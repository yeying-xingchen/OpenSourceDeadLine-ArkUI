import { DeadlineItem } from '../common/model/DeadlineModels';

const CATEGORIES: Array<string> = ['conference', 'competition', 'activity'];
const TAG_PREVIEW_COUNT: number = 12;
const LOCATION_PREVIEW_COUNT: number = 10;

@Component
export struct FilterBar {
  @Prop items: Array<DeadlineItem> = [];
  @Link selectedCategory: string | null;
  @Link selectedTags: Array<string>;
  @Link selectedLocations: Array<string>;
  @Link searchQuery: string;
  @Link showOnlyFavorites: boolean;
  @State private tagsExpanded: boolean = false;
  @State private locationsExpanded: boolean = false;
  @State private pressedLabel: string = '';
  @State private localSelectedCategory: string | null | undefined = undefined;
  private categorySyncTimer: number | undefined = undefined;

  onClearAllFilters(): void {
    this.searchQuery = '';
    this.selectedCategory = null;
    this.selectedTags = [];
    this.selectedLocations = [];
    this.showOnlyFavorites = false;
    this.tagsExpanded = false;
    this.locationsExpanded = false;
    this.pressedLabel = '';
    this.localSelectedCategory = undefined;
    if (this.categorySyncTimer !== undefined) { clearTimeout(this.categorySyncTimer); this.categorySyncTimer = undefined; }
  }

  onToggleTag(tag: string): void {
    const newTags = this.selectedTags.slice();
    const idx = newTags.indexOf(tag);
    if (idx !== -1) { newTags.splice(idx, 1); } else { newTags.push(tag); }
    this.selectedTags = newTags;
  }

  onToggleLocation(location: string): void {
    const newLocs = this.selectedLocations.slice();
    const idx = newLocs.indexOf(location);
    if (idx !== -1) { newLocs.splice(idx, 1); } else { newLocs.push(location); }
    this.selectedLocations = newLocs;
  }

  onToggleCategory(category: string): void {
    const newVal: string | null = this.selectedCategory === category ? null : category;
    this.localSelectedCategory = newVal;
    this.selectedCategory = newVal;
    if (this.categorySyncTimer !== undefined) { clearTimeout(this.categorySyncTimer); }
    this.categorySyncTimer = setTimeout(() => {
      this.localSelectedCategory = undefined;
      this.categorySyncTimer = undefined;
    }, 200);
  }

  private isCategoryActive(category: string): boolean {
    if (this.localSelectedCategory !== undefined) {
      return this.localSelectedCategory === category;
    }
    return this.selectedCategory === category;
  }

  private getCategoryDisplay(category: string): string {
    if (category === 'conference') return '会议';
    if (category === 'competition') return '竞赛';
    if (category === 'activity') return '活动';
    return category;
  }

  private getAllTags(): Array<string> {
    return Array.from(new Set(this.items.flatMap(item => item.tags))).sort();
  }
  private getAllLocations(): Array<string> {
    return Array.from(new Set(this.items.flatMap(item => item.events.map(e => e.place)))).sort();
  }

  private getVisibleTags(): Array<string> {
    const tags = this.getAllTags();
    return this.tagsExpanded ? tags : tags.slice(0, TAG_PREVIEW_COUNT);
  }

  private getVisibleLocations(): Array<string> {
    const locs = this.getAllLocations();
    return this.locationsExpanded ? locs : locs.slice(0, LOCATION_PREVIEW_COUNT);
  }

  build() {
    Column({ space: 12 }) {
      // 搜索框
      Row() {
        TextInput({ placeholder: '搜索活动...' })
          .layoutWeight(1)
          .onChange((v) => { this.searchQuery = v; });
      }
      .padding(12)
      .borderRadius(12)
      .backgroundColor(Color.White)
      .width('90%')

      // 收藏和清除
      Column() {
        Button(this.showOnlyFavorites ? '仅显示收藏' : '仅显示收藏')
          .type(ButtonType.Capsule)
          .width('60%')
          .fontSize(14)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .borderRadius(16)
          .backgroundColor(this.showOnlyFavorites ? '#007AFF' : '#F3F4F6')
          .fontColor(this.showOnlyFavorites ? '#FFFFFF' : '#111827')
          .border({ width: 1, color: this.showOnlyFavorites ? '#007AFF' : '#E5E7EB' })
          .onClick(() => { this.showOnlyFavorites = !this.showOnlyFavorites; });

        if (this.isAnyFilterActive) {
          Row() {
            Blank().layoutWeight(1)
            this.clearAllButton(() => this.onClearAllFilters())
          }
          .width('60%')
          .padding({ top: 8 })
        }
      }

      // 分类
      Flex({ justifyContent: FlexAlign.Start }) {
        ForEach(CATEGORIES, (cat: string) => {
          Column() {
            this.categoryButton(this.getCategoryDisplay(cat), this.isCategoryActive(cat), (): void => this.onToggleCategory(cat))
          }
          .layoutWeight(1)
        }, (cat: string) => cat)
      }

      // 地点
      Column() {
        this.expandButton('地点', this.locationsExpanded, () => this.locationsExpanded = !this.locationsExpanded);
        if (this.locationsExpanded) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.getVisibleLocations(), (loc: string) => {
              this.chip(loc, this.selectedLocations.includes(loc), () => this.onToggleLocation(loc));
            }, (loc: string) => loc)
          }
        }
      }

      // 标签
      Column() {
        this.expandButton('标签', this.tagsExpanded, () => this.tagsExpanded = !this.tagsExpanded);
        if (this.tagsExpanded) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.getVisibleTags(), (tag: string) => {
              this.chip(tag, this.selectedTags.includes(tag), () => this.onToggleTag(tag));
            }, (tag: string) => tag)
          }
        }
      }
    }
  }

  private get isAnyFilterActive(): boolean {
    return this.searchQuery !== '' || this.selectedCategory !== null || this.selectedTags.length > 0 || this.selectedLocations.length > 0 || this.showOnlyFavorites;
  }

  @Builder
  private chip(label: string, active: boolean, onTap: () => void) {
    Button(label)
      .type(ButtonType.Capsule)
      .fontSize(12)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(20)
      .backgroundColor(active ? '#007AFF' : '#F3F4F6')
      .fontColor(active ? '#FFFFFF' : '#111827')
      .border({ width: 1, color: active ? '#007AFF' : '#E5E7EB' })
      .scale({ x: (this.pressedLabel === label) ? 0.95 : 1, y: (this.pressedLabel === label) ? 0.95 : 1 })
      .animation({ duration: 150, curve: Curve.EaseInOut })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressedLabel = label;
        }
        if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedLabel = '';
        }
      })
      .onClick(onTap);
  }

  @Builder
  private clearAllButton(onClick: () => void) {
    Button('清除全部')
      .type(ButtonType.Capsule)
      .fontSize(12)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .borderRadius(20)
      .backgroundColor('#FEE2E2')
      .fontColor('#B91C1C')
      .onClick(onClick);
  }

  @Builder
  private expandButton(label: string, expanded: boolean, onClick: () => void) {
    Button(expanded ? `收起${label}` : `更多${label}`)
      .type(ButtonType.Capsule)
      .width('60%')
      .fontSize(14)
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .borderRadius(16)
      .backgroundColor('#F3F4F6')
      .fontColor('#111827')
      .border({ width: 1, color: '#E5E7EB' })
      .onClick(onClick);
  }

  @Builder
  private categoryButton(label: string, active: boolean, onTap: () => void) {
    Button(label)
      .type(ButtonType.Capsule)
      .fontSize(14)
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .borderRadius(16)
      .width('60%')
      .backgroundColor(active ? '#007AFF' : '#F3F4F6')
      .fontColor(active ? '#FFFFFF' : '#111827')
      .border({ width: 1, color: active ? '#007AFF' : '#E5E7EB' })
       .onClick(onTap)
       .scale({ x: (this.pressedLabel === label) ? 0.97 : 1, y: (this.pressedLabel === label) ? 0.97 : 1 })
       .onTouch((event: TouchEvent) => {
         if (event.type === TouchType.Down) { this.pressedLabel = label; }
         if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedLabel = ''; }
       });
  }
}

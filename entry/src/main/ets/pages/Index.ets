import http from '@ohos.net.http';
import { common, Want } from '@kit.AbilityKit';
import dataPreferences from '@ohos.data.preferences';
import { AppHeader } from '../components/AppHeader';
import { FilterBar } from '../components/FilterBar';
import { EventCard } from '../components/EventCard';
import { DeadlineItem, FlatEvent, EventData, TimelineEvent, CategoryType } from '../common/model/DeadlineModels';
import util from '@ohos.util';
import { registerActionHandlers, ActionHandlers } from '../common/store/ActionBus';

interface DataChangeListener { onDataReloaded?(): void; }

interface IDataSource {
  totalCount(): number;

  getData(index: number): Object;

  registerDataChangeListener(l: DataChangeListener): void;

  unregisterDataChangeListener(l: DataChangeListener): void;
}

class FlatEventDataSource implements IDataSource {
  private data: Array<FlatEvent> = [];
  private listeners: Array<DataChangeListener> = [];
  private cacheKey: string = '';
  private provider: () => Array<FlatEvent>;
  private keyFn: () => string;

  constructor(provider: () => Array<FlatEvent>, keyFn: () => string) {
    this.provider = provider;
    this.keyFn = keyFn;
  }

  private ensureFresh(): void {
    const k: string = this.keyFn();
    if (k !== this.cacheKey) {
      this.data = this.provider();
      this.cacheKey = k;
      this.listeners.forEach(l => l.onDataReloaded && l.onDataReloaded());
    }
  }

  totalCount(): number {
    this.ensureFresh();
    return this.data.length;
  }

  getData(index: number): Object {
    this.ensureFresh();
    return this.data[index];
  }

  registerDataChangeListener(l: DataChangeListener): void {
    if (this.listeners.indexOf(l) === -1) {
      this.listeners.push(l);
    }
  }

  unregisterDataChangeListener(l: DataChangeListener): void {
    const i = this.listeners.indexOf(l);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }
}

const DATA_ENDPOINT: string = 'https://oseddl.openatom.club/api/data';
const FAVORITE_STORAGE_NAME: string = 'oseddl_preferences';

@Entry
@Component
struct Index {
  @State items: Array<DeadlineItem> = [];
  @State loading: boolean = true;
  @State nowTick: number = Date.now();
  @State selectedCategory: string | null = null;
  @State selectedTags: Array<string> = [];
  @State selectedLocations: Array<string> = [];
  @State searchQuery: string = '';
  @State showOnlyFavorites: boolean = false;
  @State favorites: Array<string> = [];
  @State lastUpdated: string = '';
  @State loadError: string = '';
  @State contentOpacity: number = 0;
  private tickId: number | undefined = undefined;
  private abilityContext?: common.UIAbilityContext;
  private preferences?: dataPreferences.Preferences;
  private ds: FlatEventDataSource =
    new FlatEventDataSource(() => this.computeFilteredEvents(), () => this.buildFilterKey());

  aboutToAppear() {
    this.initialize();
    if (this.tickId === undefined) {
      this.tickId = setInterval(() => {
        this.nowTick = Date.now();
      }, 1000);
    }
  }

  aboutToDisappear() {
    if (this.tickId !== undefined) {
      clearInterval(this.tickId);
      this.tickId = undefined;
    }
  }

  private async initialize(): Promise<void> {
    try {
      this.abilityContext = getContext(this) as common.UIAbilityContext;
    } catch (err) {
      console.error(`Resolve context fail: ${JSON.stringify(err)}`);
    }
    await this.loadFavorites();
    this.registerGlobalCallbacks();
    await this.fetchItems();
    this.startContentFadeIn();
  }

  private registerGlobalCallbacks(): void {
    const handlers: ActionHandlers = {
      openLink: (url: string): void => this.openLink(url),
      toggleFavorite: (id: string): void => this.toggleFavorite(id)
    };
    registerActionHandlers(handlers);
  }

  build() {
    List({ space: 16 }) {
      // Error banner (if any)
      if (this.loadError.length > 0) {
        ListItem() {
          this.renderErrorBanner();
        }
      }
      // Loading (initial full screen)
      if (this.loading && this.items.length === 0) {
        ListItem() {
          this.renderLoading();
        }
      } else {
        // Header
        ListItem() {
          AppHeader();
        }

        // Filter bar
        ListItem() {
          FilterBar({
            items: this.items,
            selectedCategory: this.selectedCategory,
            selectedTags: this.selectedTags,
            selectedLocations: this.selectedLocations,
            searchQuery: this.searchQuery,
            showOnlyFavorites: this.showOnlyFavorites
          });
        }

        if (this.loading) {
          ListItem() {
            this.renderLoadingBanner();
          }
        }

        if (this.items.length === 0) {
          ListItem() {
            this.renderEmptyState();
          }
        } else if (this.ds.totalCount() === 0) {
          ListItem() {
            this.renderFilteredEmpty();
          }
        } else {
          if (this.contentOpacity < 1) {
            ForEach([0, 1, 2, 3], (_: number) => {
              ListItem() {
                Column() {
                  Row() {
                    Blank().width('60%').height(18).backgroundColor('#E5E7EB').borderRadius(4);
                  }
                  .margin({ bottom: 8 })

                  Row({ space: 6 }) {
                    Blank().width(48).height(14).backgroundColor('#E5E7EB').borderRadius(4);
                    Blank().width(40).height(14).backgroundColor('#E5E7EB').borderRadius(4);
                    Blank().width(56).height(14).backgroundColor('#E5E7EB').borderRadius(4);
                  }
                  .margin({ bottom: 10 })

                  Column({ space: 8 }) {
                    Blank().width('100%').height(12).backgroundColor('#E5E7EB').borderRadius(4);
                    Blank().width('85%').height(12).backgroundColor('#E5E7EB').borderRadius(4);
                    Blank().width('70%').height(12).backgroundColor('#E5E7EB').borderRadius(4);
                  }
                }
                .padding(16)
                .backgroundColor('#FFFFFF')
                .borderRadius(16)
                .shadow({
                  radius: 6,
                  color: 0x11000000,
                  offsetX: 0,
                  offsetY: 2
                })
                .opacity(0.85)
              }
            }, (_: number) => `${_}`)
          }
          LazyForEach(this.ds, (flat: FlatEvent) => {
            ListItem() {
              EventCard({ item: flat.item, event: flat.event, isFavorited: this.isFavorite(flat.event.id), nowTick: this.nowTick })
                .opacity(this.contentOpacity)
            }
          }, (flat: FlatEvent) => flat.event.id)
        }
        ListItem() {
          this.renderFooter();
        }
      }
    }
    .alignListItem(ListItemAlign.Center)
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F4F6')
  }

  private async fetchItems(): Promise<void> {
    this.loading = true;
    this.loadError = '';
    this.contentOpacity = 0;
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(DATA_ENDPOINT,
        { method: http.RequestMethod.GET, connectTimeout: 8000, readTimeout: 8000 });
      if (response.responseCode === http.ResponseCode.OK && response.result) {
        const payload: string = typeof response.result === 'string' ? (response.result as string) :
          new util.TextDecoder('utf-8').decode(new Uint8Array(response.result as ArrayBuffer));
        this.parseAndSetItems(payload);
      } else {
        this.loadError = `服务器返回异常状态: ${response.responseCode}`;
      }
    } catch (err) {
      this.loadError = `获取数据失败: ${JSON.stringify(err)}`;
    } finally {
      httpRequest.destroy();
      this.loading = false;
      this.startContentFadeIn();
    }
  }

  private parseAndSetItems(payload: string): void {
    interface RawTimelineEvent {
      deadline?: string;
      comment?: string;
    }

    interface RawEventData {
      year?: number;
      id?: string;
      link?: string;
      timeline?: Array<RawTimelineEvent>;
      timezone?: string;
      date?: string;
      place?: string;
    }

    interface RawDeadlineItem {
      title?: string;
      description?: string;
      category?: string;
      tags?: Array<string>;
      events?: Array<RawEventData>;
    }

    interface MaybeWrapped {
      data?: Array<object>;
      items?: Array<object>;
    }

    const ensureTimeline = (rawTimeline: Array<RawTimelineEvent> | undefined): Array<TimelineEvent> => {
      if (!rawTimeline) {
        return [];
      }
      const out: Array<TimelineEvent> = [];
      rawTimeline.forEach(t => {
        if (t && typeof t.deadline === 'string') {
          out.push({ deadline: t.deadline, comment: typeof t.comment === 'string' ? t.comment : '' });
        }
      });
      return out;
    };

    try {
      const parsed = JSON.parse(payload) as object | Array<object>;
      let arr: Array<object> | undefined;
      if (Array.isArray(parsed)) {
        arr = parsed;
      } else {
        const obj = parsed as MaybeWrapped;
        if (obj.data && Array.isArray(obj.data)) {
          arr = obj.data;
        } else if (obj.items && Array.isArray(obj.items)) {
          arr = obj.items;
        }
      }
      if (!arr) {
        this.loadError = '数据格式错误: 顶层不是数组';
        return;
      }

      const validated: Array<DeadlineItem> = [];
      arr.forEach(o => {
        const it = o as RawDeadlineItem;
        if (!it || typeof it.title !== 'string' || !Array.isArray(it.events)) {
          return;
        }
        const events: Array<EventData> = [];
        it.events.forEach(rawEv => {
          if (!rawEv || !Array.isArray(rawEv.timeline)) {
            return;
          }
          const timeline = ensureTimeline(rawEv.timeline);
          if (timeline.length === 0) {
            return;
          }
          events.push({
            year: typeof rawEv.year === 'number' ? rawEv.year : 0,
            id: typeof rawEv.id === 'string' ? rawEv.id : `${Date.now()}-${Math.random()}`,
            link: typeof rawEv.link === 'string' ? rawEv.link : '',
            timeline,
            timezone: typeof rawEv.timezone === 'string' ? rawEv.timezone : '',
            date: typeof rawEv.date === 'string' ? rawEv.date : '',
            place: typeof rawEv.place === 'string' ? rawEv.place : ''
          });
        });
        if (events.length === 0) {
          return;
        }
        const category: CategoryType =
          (it.category === 'conference' || it.category === 'competition' || it.category === 'activity') ?
            it.category as CategoryType : 'activity';
        validated.push({
          title: it.title,
          description: typeof it.description === 'string' ? it.description : '',
          category,
          tags: Array.isArray(it.tags) ? it.tags.map(t => String(t)) : [],
          events
        });
      });
      if (validated.length === 0) {
        this.loadError = '未解析到有效活动数据';
      } else {
        this.items = validated;
        this.lastUpdated = new Date().toLocaleString();
      }
    } catch (err) {
      this.loadError = `解析失败: ${JSON.stringify(err)}`;
    }
  }

  private buildFilterKey(): string {
    return [
      String(this.items.length),
      this.selectedCategory ?? '',
      this.selectedTags.join(','),
      this.selectedLocations.join(','),
      this.searchQuery.trim().toLowerCase(),
      this.showOnlyFavorites ? '1' : '0',
      this.favorites.join(','),
      String(this.nowTick)
    ].join('#');
  }

  private computeFilteredEvents(): Array<FlatEvent> {
    const flat = this.flattenEvents();
    const q = this.searchQuery.trim().toLowerCase();
    let result = flat;
    if (q.length > 0) {
      const tokens = q.split(/\s+/).filter(t => t.length > 0);
      result = result.filter(ev => this.matchesQuery(ev, tokens));
    }
    if (this.selectedCategory) {
      result = result.filter(ev => ev.item.category === this.selectedCategory);
    }
    if (this.selectedTags.length > 0) {
      result = result.filter(ev => this.selectedTags.some(tag => ev.item.tags.indexOf(tag) !== -1));
    }
    if (this.selectedLocations.length > 0) {
      result = result.filter(ev => this.selectedLocations.indexOf(ev.event.place) !== -1);
    }
    if (this.showOnlyFavorites) {
      result = result.filter(ev => this.isFavorite(ev.event.id));
    }
    return result.sort((a, b) => {
      const aEnded = a.timeRemaining < 0;
      const bEnded = b.timeRemaining < 0;
      if (aEnded !== bEnded) {
        return aEnded ? 1 : -1;
      }
      if (aEnded && bEnded) {
        return b.timeRemaining - a.timeRemaining;
      }
      return a.timeRemaining - b.timeRemaining;
    });
  }

  private flattenEvents(): Array<FlatEvent> {
    const now = Date.now();
    const out: Array<FlatEvent> = [];
    this.items.forEach(item => {
      item.events.forEach(ev => {
        const deadlines: Array<number> = ev.timeline.map(t => new Date(t.deadline).getTime()).filter(ts => !isNaN(ts));
        let remaining = Number.MAX_VALUE;
        if (deadlines.length > 0) {
          deadlines.sort((a, b) => a - b);
          const next = deadlines.find(ts => ts >= now) ?? deadlines[deadlines.length - 1];
          remaining = next - now;
        }
        out.push({ item, event: ev, timeRemaining: remaining });
      });
    });
    return out;
  }

  private matchesQuery(ev: FlatEvent, tokens: Array<string>): boolean {
    const content =
      [ev.item.title, ev.item.description, ev.item.tags.join(' '), ev.event.place].join(' ').toLowerCase();
    return tokens.every(t => content.indexOf(t) !== -1);
  }

  private isFavorite(id: string): boolean {
    return this.favorites.indexOf(id) !== -1;
  }

  private toggleFavorite(id: string): void {
    if (!this.preferences) {
      this.loadFavorites().then(() => this.toggleFavorite(id));
      return;
    }
    const idx = this.favorites.indexOf(id);
    if (idx !== -1) {
      this.favorites.splice(idx, 1);
    } else {
      this.favorites.push(id);
    }
    this.persistFavorites();
    // DataSource will refresh lazily on next List query via key change
  }

  private async loadFavorites(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      this.preferences = await dataPreferences.getPreferences(context, FAVORITE_STORAGE_NAME);
      const stored = await this.preferences.get('favorites', '[]');
      if (typeof stored === 'string') {
        this.favorites = JSON.parse(stored) as Array<string>;
      } else if (Array.isArray(stored)) {
        this.favorites = (stored as Array<string | number>).map(v => `${v}`);
      } else {
        this.favorites = [];
      }
    } catch (err) {
      this.favorites = [];
    }
  }

  private async persistFavorites(): Promise<void> {
    if (!this.preferences) {
      return;
    }
    try {
      await this.preferences.put('favorites', JSON.stringify(this.favorites));
      await this.preferences.flush();
    } catch (_e) {
    }
  }

  private openLink(url: string): void {
    if (!url) {
      return;
    }
    try {
      if (!this.abilityContext) {
        this.abilityContext = getContext(this) as common.UIAbilityContext;
      }
      if (!this.abilityContext) {
        return;
      }
      const want: Want = { action: 'ohos.want.action.viewData', uri: url };
      this.abilityContext.startAbility(want)
        .catch((err: Error | object) => console.error(`Open link fail: ${JSON.stringify(err)}`));
    } catch (err) {
      console.error(`Open link exception: ${JSON.stringify(err)}`);
    }
  }

  private startContentFadeIn(): void {
    if (this.ds.totalCount() === 0) {
      return;
    }
    this.contentOpacity = 0;
    animateTo({ duration: 350, curve: Curve.EaseInOut }, () => {
      this.contentOpacity = 1;
    });
  }

  // UI builders
  @Builder
  private renderLoading() {
    Column({ space: 12 }) {
      LoadingProgress().width(48).height(48);
      Text('正在加载活动…').fontColor('#4B5563');
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder
  private renderLoadingBanner() {
    Row({ space: 8 }) {
      LoadingProgress().width(24).height(24);
      Text('正在刷新最新活动数据…').fontColor('#4B5563');
    }
    .padding({
      left: 12,
      right: 12,
      top: 12,
      bottom: 12
    })
    .backgroundColor('#E0F2FE')
    .borderRadius(12)
  }

  @Builder
  private renderEmptyState() {
    Column({ space: 12 }) {
      Text('? 未找到任何活动').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#111827');
      Text('请尝试调整筛选条件或修改搜索关键词。')
        .fontSize(14)
        .fontColor('#4B5563')
        .textAlign(TextAlign.Center)
        .lineHeight(20);
    }
    .padding({
      left: 16,
      right: 16,
      top: 48,
      bottom: 48
    })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  @Builder
  private renderFooter() {
    Column({ space: 6 }) {
      Text('华科开放原子开源俱乐部维护')
        .fontSize(12)
        .fontColor('#4B5563')
        .textAlign(TextAlign.Center);
      if (this.lastUpdated.length > 0) {
        Text(`上次更新：${this.lastUpdated}`).fontSize(11).fontColor('#9CA3AF').textAlign(TextAlign.Center);
      }
    }
    .padding({ top: 24, bottom: 32 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private renderErrorBanner() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('加载失败').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#B91C1C')
        Text(this.loadError)
          .fontSize(12)
          .fontColor('#7F1D1D')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      Row({ space: 12 }) {
        Button('重试')
          .type(ButtonType.Capsule)
          .fontSize(12)
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#DC2626' })
          .fontColor('#B91C1C')
          .onClick(() => {
            this.fetchItems();
          })
        if (!this.loading && this.items.length > 0) {
          Button('忽略')
            .type(ButtonType.Capsule)
            .fontSize(12)
            .backgroundColor('#F3F4F6')
            .fontColor('#374151')
            .onClick(() => {
              this.loadError = '';
            })
        }
      }
    }
    .padding({
      left: 12,
      right: 12,
      top: 12,
      bottom: 12
    })
    .backgroundColor('#FEE2E2')
    .borderRadius(12)
    .margin({
      left: 16,
      right: 16,
      top: 8,
      bottom: 4
    })
  }

  @Builder
  private renderFilteredEmpty() {
    Column({ space: 12 }) {
      Text('筛选结果为空').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#111827')
      Text('当前筛选条件未匹配任何活动，尝试放宽或清除筛选。')
        .fontSize(13)
        .fontColor('#4B5563')
        .textAlign(TextAlign.Center)
        .lineHeight(18)
      Button('清除筛选')
        .type(ButtonType.Capsule)
        .fontSize(13)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#D1D5DB' })
        .fontColor('#374151')
        .onClick(() => {
          this.selectedCategory = null;
          this.selectedTags.splice(0, this.selectedTags.length);
          this.selectedLocations.splice(0, this.selectedLocations.length);
          this.showOnlyFavorites = false;
          this.searchQuery = '';
        })
    }
    .padding({
      left: 16,
      right: 16,
      top: 40,
      bottom: 40
    })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .margin({ left: 16, right: 16, top: 8, bottom: 4 })
    .alignItems(HorizontalAlign.Center)
  }
}
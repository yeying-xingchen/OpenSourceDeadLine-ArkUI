import { common, Want } from '@kit.AbilityKit';

@Component
export struct AppHeader {
  build() {
    Column({ space: 12 }) {
      // 标题行（点击打开仓库）
      Row() {
        Text('开源活动截止日期')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
          .lineHeight(24)
          .margin(14)
          .onClick(() => { this.openRepo(); })
      }
      // 副标题与说明
      Text('聚合开源会议、竞赛与活动关键时间点，帮助及时提交与参与。')
        .fontSize(14)
        .fontColor('#6B7280')
        .lineHeight(20)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text('※ 数据人工整理，仅供参考')
        .fontSize(11)
        .fontColor('#6B7280')
        .lineHeight(16)
    }
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({ radius: 8, color: '#0000000F', offsetX: 0, offsetY: 2 })
  }

  private openRepo() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      if (!context) { return; }
      const want: Want = {
        uri: 'https://github.com/hust-open-atom-club/open-source-deadlines',
        action: 'ohos.want.action.viewData'
      };
      context.startAbility(want).catch((err: Error | object) => {
        console.error(`Failed to launch GitHub link: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      console.error(`Failed to open GitHub link: ${JSON.stringify(err)}`);
    }
  }
}

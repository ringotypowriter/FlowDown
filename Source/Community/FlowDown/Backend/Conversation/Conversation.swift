//
//  Conversation.swift
//  FlowDown
//
//  Created by 秋星桥 on 2024/12/31.
//

import Combine
import ConfigurableKit
import Foundation
import OrderedCollections

class Conversation: Identifiable, Codable, Equatable {
    var id: UUID = .init()

    var cancellable: Set<AnyCancellable> = []

    var metadata: Metadata = .init() {
        didSet { dispatchMetadataUpdates() }
    }

    var messages: OrderedDictionary<Message.ID, Message> = .init() {
        didSet { dispatchMessageUpdates() }
    }

    var isGenerating: Bool = false

    init() {
        ConfigurableKit.publisher(forKey: ServiceProvider.ModelType.textCompletion.defaultKey, type: String.self)
            .ensureMainThread()
            .sink { [weak self] _ in
                self?.updateDefaultModel()
            }
            .store(in: &cancellable)
    }

    deinit {
        delegates.removeAll()
    }

    enum CodingKeys: CodingKey {
        case id
        case metadata
        case messages
    }

    var delegates: [DelegateBox] = []

    func updateDefaultModel() {
        if let modelIdentifier = metadata.modelIdentifier,
           let provider = ServiceProviders.get(id: metadata.providerIdentifier),
           provider.enabledModels[.textCompletion, default: []].contains(modelIdentifier)
        { return }

        metadata.providerIdentifier = nil
        metadata.modelIdentifier = nil

        guard let defaultModel = ServiceProvider.ModelType.textCompletion.getDefault(),
              !defaultModel.isEmpty
        else { return }
        let providers = ServiceProviders.get()
        for provider in providers {
            for modelIdentifier in provider.models[.textCompletion, default: []] {
                let match = Settings.modelDefaultValue(
                    modelIdentifier: modelIdentifier,
                    withType: .textCompletion,
                    serviceProvider: provider
                )
                if match == defaultModel {
                    metadata.providerIdentifier = provider.id
                    metadata.modelIdentifier = modelIdentifier
                    return
                }
            }
        }
    }

    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }
}

extension Conversation {
    var isEmpty: Bool { messages.isEmpty }
}

#if DEBUG
    extension Conversation {
        private func getMeSomeTestMessages() {
            var newMessageList: [Message] = []
            func process(message: Message) { newMessageList.append(message) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
                defer { self.messages = .init(uniqueKeysWithValues: newMessageList.map { ($0.id, $0) }) }
                for _ in 0 ... 10 {
                    process(message: .init(
                        conversationIdentifier: id,
                        participant: .user,
                        document: "你好！帮我整理一下退票时间的表格。"
                    ))
                    process(message: .init(
                        conversationIdentifier: id,
                        participant: .assistant,
                        document:
                        ###"""
                        好的，这是你要的表格：

                        | 申请退票时间段 | 退票手续费 |
                        | ---- | ---- |
                        | ~~04/12 12:30 至 014/14 12:30~~ | ~~免费退票~~ |
                        | ~~04/15 12:30 至 014/16 12:30~~ | ~~扣除票价 20% 手续费~~ |
                        | ~~04/15 12:30 至 014/16 12:30~~ | ~~扣除票价 50% 手续费~~ |
                        | **04/15 12:30 至 014/16 12:30** | **扣除票价 75% 手续费** |
                        | 04/15 12:30 至 014/16 12:30 | 不设退款 |

                        下面是生成这段表格的代码：
                        ```swift
                        import Foundation

                        print("Hello World!")
                        ```

                        请问还有其他需要帮助的吗？ ~~没有的对吧~~
                        """###
                    ))
                    process(message: .init(
                        conversationIdentifier: id,
                        participant: .user,
                        document: "我想压力测试一下我们的 Markdown 渲染器 写长一点多一点我看看呢"
                    ))
                    process(message: .init(
                        conversationIdentifier: id,
                        participant: .assistant,
                        document:
                        ###"""
                        好的！以下是一段较长的 Markdown 示例文本，包含多种格式和元素，供你测试渲染器的表现：

                        ---

                        # Markdown 渲染器压力测试

                        这是一个用于测试 Markdown 渲染器的示例文档。我们将尝试包含尽可能多的 Markdown 元素，以确保渲染器能够正确处理各种格式。

                        ## 1. 标题

                        Markdown 支持多级标题，从 `#` 到 `######`，分别对应 HTML 中的 `<h1>` 到 `<h6>`。

                        ### 1.1 二级标题

                        #### 1.1.1 三级标题

                        ##### 1.1.1.1 四级标题

                        ###### 1.1.1.1.1 五级标题

                        ###### 1.1.1.1.1.1 六级标题

                        ---

                        ## 2. 段落和换行

                        这是一个普通段落。Markdown 中的段落由一个或多个连续的文本行组成，段落之间需要空一行。

                        这是另一个段落。  
                        如果你想在段落内换行，可以在行尾添加两个空格，或者使用 `<br>` 标签。

                        ---

                        ## 3. 强调

                        你可以使用以下方式强调文本：

                        - **加粗**：使用 `**` 或 `__` 包裹文本。
                        - *斜体*：使用 `*` 或 `_` 包裹文本。
                        - ***加粗且斜体***：使用 `***` 或 `___` 包裹文本。
                        - ~~删除线~~：使用 `~~` 包裹文本。

                        ---

                        ## 4. 列表

                        ### 4.1 无序列表

                        - 项目 1
                        - 项目 2
                          - 子项目 2.1
                          - 子项目 2.2
                        - 项目 3

                        ### 4.2 有序列表

                        1. 第一项
                        2. 第二项
                           1. 子项 2.1
                           2. 子项 2.2
                        3. 第三项

                        ---

                        ## 5. 链接和图片

                        - [这是一个链接](https://example.com)
                        - ![这是一张图片](https://example.com/image.png)

                        ---

                        ## 6. 代码

                        ### 6.1 行内代码

                        你可以使用反引号包裹行内代码，例如 `print("Hello, World!")`。

                        ### 6.2 代码块

                        ```python
                        def hello_world():
                            print("Hello, World!")
                        ```

                        ```javascript
                        function helloWorld() {
                            console.log("Hello, World!");
                        }
                        ```

                        ---

                        ## 7. 引用

                        > 这是一个引用块。引用块可以嵌套。
                        >
                        > > 这是一个嵌套的引用块。

                        ---

                        ## 8. 表格

                        | 序号 | 名称       | 描述           |
                        | ---- | ---------- | -------------- |
                        | 1    | 项目 A     | 这是项目 A     |
                        | 2    | 项目 B     | 这是项目 B     |
                        | 3    | 项目 C     | 这是项目 C     |

                        ---

                        ## 9. 分隔线

                        你可以使用 `---`、`***` 或 `___` 创建分隔线。

                        ---

                        ## 10. 内嵌 HTML

                        Markdown 支持内嵌 HTML，例如：

                        <p style="color: red;">这是一个红色的段落。</p>

                        ---

                        ## 11. 脚注

                        这是一个脚注示例[^1]。

                        [^1]: 这是脚注的内容。

                        ---

                        ## 12. 任务列表

                        - [x] 完成任务 1
                        - [ ] 完成任务 2
                        - [ ] 完成任务 3

                        ---

                        ## 13. 数学公式（如果支持）

                        Markdown 可以通过 LaTeX 语法渲染数学公式，例如：

                        $$
                        E = mc^2
                        $$

                        或者行内公式：\( \sum_{i=1}^n i = \frac{n(n+1)}{2} \)

                        ---

                        ## 14. 其他

                        - **特殊字符**：`*`、`_`、`#`、`~` 等字符需要转义。
                        - **表情符号**：😊、🚀、🎉
                        - **高亮**：==高亮文本==（如果支持）

                        ---

                        希望这段 Markdown 示例能帮助你全面测试渲染器的表现！如果有任何问题或需要进一步调整，请告诉我。
                        """###
                    ))
                    process(message: .init(
                        conversationIdentifier: id,
                        participant: .user,
                        document: "给我写点小说吧"
                    ))
                    process(message: .init(
                        conversationIdentifier: id,
                        participant: .assistant,
                        document:
                        ###"""
                        当然！以下是一段原创小说的开头，设定在一个充满神秘色彩的奇幻世界中。如果你喜欢这个风格，我可以继续扩展故事。

                        ---

                        ### **《星辰之痕》**

                        #### **第一章：破碎的预言**

                        夜幕低垂，星辰如碎银般洒落在天际。艾琳娜站在高塔的顶端，凝视着远方那片被黑暗吞噬的森林。风从她的耳边呼啸而过，带着一丝寒意，仿佛在低语着什么。

                        “预言……真的会实现吗？”她轻声自语，手指不自觉地抚摸着胸前的那枚古老吊坠。吊坠上刻着一颗星辰，星辰的中心有一道细微的裂痕，仿佛随时会碎裂。

                        那是她的家族传承之物，据说与一个古老的预言有关。预言中提到，当星辰破碎之时，世界将陷入永恒的黑暗，唯有“星辰之子”才能拯救一切。

                        艾琳娜从未相信过这些传说。她只是一个普通的学者，专注于研究古代符文和魔法典籍。然而，最近发生的一切却让她不得不重新审视这些看似荒诞的故事。

                        三天前，她在图书馆的深处发现了一本被尘封的古籍。书页已经泛黄，边缘甚至有些破损，但上面的符文却依然清晰可见。当她试图解读这些符文时，吊坠突然发出了微弱的光芒，仿佛在回应着什么。

                        “艾琳娜！”一个熟悉的声音打断了她的思绪。她转过身，看到她的好友兼助手——莱昂，正急匆匆地跑上高塔。

                        “怎么了？”她问道，心中隐隐有些不安。

                        “出事了！”莱昂气喘吁吁地说道，“森林里……出现了奇怪的生物！它们……它们像是从黑暗中诞生的！”

                        艾琳娜的心猛地一沉。她快步走到高塔的边缘，望向那片森林。果然，森林的边缘隐约可见一些模糊的身影，它们移动得极快，仿佛没有实体。

                        “预言中的黑暗……已经开始了吗？”她喃喃道。

                        “我们必须做点什么！”莱昂急切地说道。

                        艾琳娜握紧了吊坠，感受着它传来的微弱温度。她知道，自己不能再逃避了。无论预言是真是假，她都必须面对这一切。

                        “走吧，”她坚定地说道，“我们去森林。”

                        ---

                        #### **第二章：黑暗的觉醒**

                        森林中弥漫着一股诡异的气息，仿佛连空气都变得沉重。艾琳娜和莱昂小心翼翼地穿行在树木之间，手中的火把勉强照亮了前方的路。

                        “这些生物到底是什么？”莱昂低声问道，声音中带着一丝颤抖。

                        “我不知道，”艾琳娜摇了摇头，“但它们绝对不是普通的野兽。”

                        突然，前方的灌木丛中传来一阵沙沙声。两人立刻停下脚步，屏住呼吸。紧接着，一个黑影从灌木丛中窜出，直扑向他们！

                        艾琳娜迅速举起手中的法杖，口中念出一串古老的咒语。一道光芒从法杖顶端射出，击中了那个黑影。黑影发出一声尖锐的嘶吼，随即化作一团黑烟消散。

                        “这些生物……它们怕光！”艾琳娜惊呼道。

                        “那我们得快点找到它们的源头！”莱昂说道。

                        两人加快了脚步，朝着森林深处前进。随着他们越来越深入，周围的黑暗也变得越来越浓重。艾琳娜感觉到吊坠的温度在逐渐升高，仿佛在指引着她。

                        终于，他们来到了一片空地。空地的中央矗立着一座古老的石碑，石碑上刻满了与吊坠上相似的符文。而在石碑的周围，无数黑影正在聚集，仿佛在等待着什么。

                        “这就是源头……”艾琳娜低声说道。

                        就在这时，石碑上的符文突然亮了起来，一道刺眼的光芒直冲天际。艾琳娜感觉到一股强大的力量从吊坠中涌出，与石碑的光芒产生了共鸣。

                        “星辰之子……”一个低沉的声音在她耳边响起，“你终于来了。”

                        ---

                        ### **待续**

                        如果你喜欢这个故事，我可以继续扩展后续的情节，或者根据你的需求调整风格和设定！
                        """###
                    ))

                    process(message: .init(
                        conversationIdentifier: id,
                        participant: .user,
                        document: "我想学习一下 Swift 编程"
                    ))
                    process(message: .init(
                        conversationIdentifier: id,
                        participant: .assistant,
                        document:
                        ###"""
                        当然！以下是一个简单的 Swift 代码示例，展示了如何创建一个基本的 iOS 应用，包含一个按钮和一个标签。当用户点击按钮时，标签的文本会更新。

                        ```swift
                        import UIKit

                        class ViewController: UIViewController {
                            // 创建一个标签
                            let label: UILabel = {
                                let label = UILabel()
                                label.text = "Hello, World!"
                                label.textAlignment = .center
                                label.font = UIFont.systemFont(ofSize: 24)
                                label.translatesAutoresizingMaskIntoConstraints = false
                                return label
                            }()

                            // 创建一个按钮
                            let button: UIButton = {
                                let button = UIButton(type: .system)
                                button.setTitle("Click Me", for: .normal)
                                button.titleLabel?.font = UIFont.systemFont(ofSize: 18)
                                button.translatesAutoresizingMaskIntoConstraints = false
                                return button
                            }()

                            override func viewDidLoad() {
                                super.viewDidLoad()

                                // 设置背景颜色
                                view.backgroundColor = .white

                                // 添加标签到视图
                                view.addSubview(label)

                                // 添加按钮到视图
                                view.addSubview(button)

                                // 设置标签的约束
                                NSLayoutConstraint.activate([
                                    label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                    label.topAnchor.constraint(equalTo: view.topAnchor, constant: 100)
                                ])

                                // 设置按钮的约束
                                NSLayoutConstraint.activate([
                                    button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                    button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20)
                                ])

                                // 添加按钮点击事件
                                button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
                            }

                            // 按钮点击事件处理
                            @objc func buttonTapped() {
                                label.text = "Button Clicked!"
                            }
                        }
                        ```

                        ### 代码说明：
                        1. **UI 元素**：
                           - `UILabel`：用于显示文本。
                           - `UIButton`：用于触发事件。

                        2. **布局**：
                           - 使用 `NSLayoutConstraint` 设置标签和按钮的布局约束，确保它们在屏幕上的位置正确。

                        3. **事件处理**：
                           - 使用 `addTarget` 方法为按钮添加点击事件处理函数 `buttonTapped`，当按钮被点击时，标签的文本会更新为 "Button Clicked!"。

                        ### 运行效果：
                        - 应用启动后，屏幕上会显示一个标签和一个按钮。
                        - 点击按钮后，标签的文本会从 "Hello, World!" 变为 "Button Clicked!"。

                        如果你需要更复杂的 Swift 代码示例或有其他需求，请告诉我！
                        """###
                    ))
                }
            }
        }
    }
#endif

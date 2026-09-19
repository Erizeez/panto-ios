import Foundation

/// MockPantoClient 是符合 PantoClientProtocol 的高保真内存模拟实现。
/// 用于脱机独立开发、交互测试以及 SwiftUI Previews。
public final class MockPantoClient: PantoClientProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var currentMode: TunnelMode = .rule
    private var globalTarget: String? = "🇸🇬 新加坡 01"
    private var isRunning: Bool = true
    private var startTimestamp: Date = Date().addingTimeInterval(-3720) // 1 hour ago
    
    private var groups: [GroupItem] = [
        GroupItem(
            id: "⚡ 节点选择 (Proxy)",
            kind: "select",
            members: ["🇸🇬 新加坡 01", "🇯🇵 东京 02", "🇭🇰 香港 01", "🇺🇸 圣何塞 03", "DIRECT"],
            current: "🇸🇬 新加坡 01",
            delays: ["🇸🇬 新加坡 01": 42, "🇯🇵 东京 02": 68, "🇭🇰 香港 01": 28, "🇺🇸 圣何塞 03": 145, "DIRECT": 5]
        ),
        GroupItem(
            id: "🚀 自动选优 (Auto)",
            kind: "url-test",
            members: ["🇸🇬 新加坡 01", "🇯🇵 东京 02", "🇭🇰 香港 01"],
            current: "🇭🇰 香港 01",
            delays: ["🇸🇬 新加坡 01": 42, "🇯🇵 东京 02": 68, "🇭🇰 香港 01": 28]
        ),
        GroupItem(
            id: "🏫 校园与企业内网 (Campus)",
            kind: "select",
            members: ["🏢 IKEv2 网关", "🌐 Tailscale 网格", "DIRECT"],
            current: "🏢 IKEv2 网关",
            delays: ["🏢 IKEv2 网关": 12, "🌐 Tailscale 网格": 18, "DIRECT": 6]
        ),
        GroupItem(
            id: "🛡️ 容灾备用 (Fallback)",
            kind: "fallback",
            members: ["🇸🇬 新加坡 01", "DIRECT"],
            current: "🇸🇬 新加坡 01",
            delays: ["🇸🇬 新加坡 01": 42, "DIRECT": 5]
        )
    ]

    private var topologyNodes: [TopologyNodeItem] = [
        TopologyNodeItem(
            id: "DIRECT",
            kind: "direct",
            underlay: nil,
            effectiveMtu: 1500,
            overhead: 0,
            dependents: ["🏢 IKEv2 网关", "🇸🇬 新加坡 01", "DIRECT-LAN"],
            path: ["DIRECT"]
        ),
        TopologyNodeItem(
            id: "🏢 IKEv2 网关",
            kind: "ikev2",
            underlay: "DIRECT",
            effectiveMtu: 1420,
            overhead: 80,
            dependents: ["🌐 Tailscale 网格"],
            path: ["DIRECT", "🏢 IKEv2 网关"]
        ),
        TopologyNodeItem(
            id: "🌐 Tailscale 网格",
            kind: "tailscale",
            underlay: "🏢 IKEv2 网关",
            effectiveMtu: 1280,
            overhead: 140,
            dependents: ["ExitNode-Tokyo"],
            path: ["DIRECT", "🏢 IKEv2 网关", "🌐 Tailscale 网格"]
        ),
        TopologyNodeItem(
            id: "ExitNode-Tokyo",
            kind: "wireguard",
            underlay: "🌐 Tailscale 网格",
            effectiveMtu: 1240,
            overhead: 40,
            dependents: nil,
            path: ["DIRECT", "🏢 IKEv2 网关", "🌐 Tailscale 网格", "ExitNode-Tokyo"]
        ),
        TopologyNodeItem(
            id: "🇸🇬 新加坡 01",
            kind: "shadowsocks",
            underlay: "DIRECT",
            effectiveMtu: 1460,
            overhead: 40,
            dependents: nil,
            path: ["DIRECT", "🇸🇬 新加坡 01"]
        )
    ]

    private var magicConflicts: [MagicIPConflictItem] = [
        MagicIPConflictItem(
            ip: "100.64.0.18",
            candidates: [
                MagicIPCandidate(endpointId: "ep-work-mbp", priority: 10, hostname: "Work-MacBook-Pro", dnsName: "work-mbp.ts.net", online: true),
                MagicIPCandidate(endpointId: "ep-home-nas", priority: 5, hostname: "Home-Synology-NAS", dnsName: "home-nas.ts.net", online: true)
            ],
            detectedAt: "2026-09-19T10:15:00Z",
            lastUsedEndpoint: "Work-MacBook-Pro"
        )
    ]

    private var magicChoices: [MagicIPChoiceItem] = []

    private var rules: [RuleItem] = [
        RuleItem(type: "domain-suffix", payload: "apple.com", target: "DIRECT"),
        RuleItem(type: "domain-suffix", payload: "icloud.com", target: "DIRECT"),
        RuleItem(type: "domain-suffix", payload: "google.com", target: "⚡ 节点选择 (Proxy)"),
        RuleItem(type: "domain-suffix", payload: "github.com", target: "⚡ 节点选择 (Proxy)"),
        RuleItem(type: "domain-suffix", payload: "openai.com", target: "⚡ 节点选择 (Proxy)"),
        RuleItem(type: "ip-cidr", payload: "100.64.0.0/10", target: "🌐 Tailscale 网格"),
        RuleItem(type: "geoip", payload: "CN", target: "DIRECT"),
        RuleItem(type: "match", payload: "", target: "⚡ 节点选择 (Proxy)")
    ]

    private var observationConsents: [ObservationConsentItem] = [
        ObservationConsentItem(
            endpointId: "ep-corporate-proxy",
            endpointName: "🏢 企业合规审计节点",
            targetDomain: "internal.enterprise.corp",
            requestedAt: "2026-09-19T11:00:00Z",
            reason: "检测到企业内网流量，远端网关请求出站观测与遥测授权"
        )
    ]

    private var probeSites: [ProbeSite] = [
        // 开发者与代码平台
        ProbeSite(id: "site-github", name: "GitHub", domain: "github.com", port: 443, category: "开发平台", icon: "chevron.left.forwardslash.chevron.right", description: "全球开发者代码协作平台"),
        ProbeSite(id: "site-npm", name: "NPM Registry", domain: "registry.npmjs.org", port: 443, category: "开发平台", icon: "shippingbox.fill", description: "Node.js 官方依赖镜像"),
        ProbeSite(id: "site-docker", name: "Docker Hub", domain: "hub.docker.com", port: 443, category: "开发平台", icon: "cube.box.fill", description: "全球容器镜像中心"),
        ProbeSite(id: "site-huggingface", name: "Hugging Face", domain: "huggingface.co", port: 443, category: "开发平台", icon: "face.smiling.fill", description: "开源 AI 模型与数据集社区"),
        // 国际搜索与基础设施
        ProbeSite(id: "site-google", name: "Google", domain: "google.com", port: 443, category: "国际搜索", icon: "globe", description: "国际搜索引擎与基础设施"),
        ProbeSite(id: "site-cloudflare", name: "Cloudflare 1.1.1.1", domain: "1.1.1.1", port: 443, category: "网络基础设施", icon: "bolt.shield.fill", description: "全球低延迟 Anycast 边缘网络"),
        ProbeSite(id: "site-aws", name: "AWS Global", domain: "aws.amazon.com", port: 443, category: "网络基础设施", icon: "server.rack", description: "亚马逊全球云计算骨干网"),
        ProbeSite(id: "site-vercel", name: "Vercel Edge", domain: "vercel.com", port: 443, category: "网络基础设施", icon: "triangle.fill", description: "现代 Web 全球边缘网络"),
        // 大语言模型与 AI 平台
        ProbeSite(id: "site-openai", name: "OpenAI API", domain: "api.openai.com", port: 443, category: "AI 基础设施", icon: "sparkles", description: "ChatGPT 与 GPT-4o 核心网关"),
        ProbeSite(id: "site-claude", name: "Claude AI", domain: "claude.ai", port: 443, category: "AI 基础设施", icon: "brain.head.profile", description: "Anthropic 智能对话系统"),
        ProbeSite(id: "site-gemini", name: "Google Gemini", domain: "gemini.google.com", port: 443, category: "AI 基础设施", icon: "wand.and.stars", description: "多模态大模型推理接口"),
        // 跨国社交与百科流媒体
        ProbeSite(id: "site-x", name: "X (Twitter)", domain: "x.com", port: 443, category: "国际社交", icon: "bubble.left.and.bubble.right.fill", description: "实时动态社交平台"),
        ProbeSite(id: "site-telegram", name: "Telegram Web", domain: "web.telegram.org", port: 443, category: "国际社交", icon: "paperplane.fill", description: "加密即时通讯网络"),
        ProbeSite(id: "site-wikipedia", name: "Wikipedia", domain: "wikipedia.org", port: 443, category: "国际媒体", icon: "book.fill", description: "全球多语言自由百科全书"),
        ProbeSite(id: "site-youtube", name: "YouTube", domain: "youtube.com", port: 443, category: "国际流媒体", icon: "play.rectangle.fill", description: "国际高码率视频流媒体"),
        ProbeSite(id: "site-netflix", name: "Netflix", domain: "netflix.com", port: 443, category: "国际流媒体", icon: "film.fill", description: "全球 4K HDR 视频流媒体"),
        ProbeSite(id: "site-spotify", name: "Spotify", domain: "spotify.com", port: 443, category: "国际流媒体", icon: "waveform", description: "全球高品质音频流媒体"),
        // 苹果生态
        ProbeSite(id: "site-apple", name: "Apple Services", domain: "apple.com", port: 443, category: "系统生态", icon: "apple.logo", description: "iCloud 与 CDN 基础设施"),
        // 校园网与企业内网
        ProbeSite(id: "site-campus-portal", name: "校园办事大厅", domain: "portal.edu.cn", port: 443, category: "校园内网", icon: "building.columns.fill", description: "校园高可用统一身份认证"),
        ProbeSite(id: "site-campus-jw", name: "校园教务系统", domain: "jwxt.edu.cn", port: 443, category: "校园内网", icon: "graduationcap.fill", description: "教务内网选课与选拔通道"),
        ProbeSite(id: "site-campus-mirror", name: "高校开源镜像站", domain: "mirrors.tuna.tsinghua.edu.cn", port: 443, category: "校园内网", icon: "arrow.down.doc.fill", description: "校园千兆本地镜像加速"),
        // 国内直连高频服务
        ProbeSite(id: "site-bilibili", name: "哔哩哔哩", domain: "bilibili.com", port: 443, category: "国内直连", icon: "play.tv.fill", description: "国内主站直连流媒体"),
        ProbeSite(id: "site-baidu", name: "百度搜索", domain: "baidu.com", port: 443, category: "国内直连", icon: "magnifyingglass", description: "国内基础搜索引擎"),
        ProbeSite(id: "site-qq", name: "微信互联中心", domain: "qq.com", port: 443, category: "国内直连", icon: "message.fill", description: "腾讯即时通信直连网关"),
        // 游戏与跨国云协同
        ProbeSite(id: "site-discord", name: "Discord", domain: "discord.com", port: 443, category: "国际社交", icon: "bubble.middle.bottom.fill", description: "低延迟语音与社区网络"),
        ProbeSite(id: "site-steam", name: "Steam Store", domain: "steampowered.com", port: 443, category: "国际媒体", icon: "gamecontroller.fill", description: "全球数字游戏分发与 CDN"),
        ProbeSite(id: "site-gitlab", name: "GitLab", domain: "gitlab.com", port: 443, category: "开发平台", icon: "terminal.fill", description: "企业级代码托管与 CI/CD"),
        ProbeSite(id: "site-grafana", name: "Grafana Cloud", domain: "grafana.net", port: 443, category: "开发平台", icon: "chart.xyaxis.line", description: "分布式云原生观测平台"),
        ProbeSite(id: "site-cloud-ali", name: "阿里云国际站", domain: "alibabacloud.com", port: 443, category: "网络基础设施", icon: "cloud.fill", description: "亚太边缘跨境专线网络"),
        ProbeSite(id: "site-apple-testflight", name: "TestFlight CDN", domain: "testflight.apple.com", port: 443, category: "系统生态", icon: "airplane.circle.fill", description: "iOS 测试应用分发 CDN"),
        // 扩展大模型与前沿 AI
        ProbeSite(id: "site-deepseek", name: "DeepSeek API", domain: "api.deepseek.com", port: 443, category: "AI 基础设施", icon: "sparkle", description: "推理与代码生成大模型"),
        ProbeSite(id: "site-perplexity", name: "Perplexity AI", domain: "perplexity.ai", port: 443, category: "AI 基础设施", icon: "brain", description: "对话式实时搜索智能体"),
        ProbeSite(id: "site-groq", name: "Groq LPU", domain: "groq.com", port: 443, category: "AI 基础设施", icon: "bolt.fill", description: "超高速硬件加速大模型推理"),
        ProbeSite(id: "site-mistral", name: "Mistral AI", domain: "mistral.ai", port: 443, category: "AI 基础设施", icon: "wind", description: "开源与商业模型前沿网关"),
        // 扩展现代开发者工具链
        ProbeSite(id: "site-supabase", name: "Supabase", domain: "supabase.com", port: 443, category: "开发平台", icon: "bolt.horizontal.fill", description: "开源 Firebase 替代架构"),
        ProbeSite(id: "site-sentry", name: "Sentry.io", domain: "sentry.io", port: 443, category: "开发平台", icon: "ant.fill", description: "应用异常性能监控平台"),
        ProbeSite(id: "site-redis", name: "Redis Cloud", domain: "redislabs.com", port: 443, category: "开发平台", icon: "cylinder.split.1x2.fill", description: "全球分布式内存缓存网络"),
        ProbeSite(id: "site-postman", name: "Postman API", domain: "postman.com", port: 443, category: "开发平台", icon: "arrow.up.right.video.fill", description: "API 协同与测试中心"),
        ProbeSite(id: "site-raycast", name: "Raycast Store", domain: "raycast.com", port: 443, category: "系统生态", icon: "command", description: "快捷指令与扩展市场"),
        // 国际云骨干与海外节点
        ProbeSite(id: "site-azure", name: "Azure Global", domain: "azure.microsoft.com", port: 443, category: "网络基础设施", icon: "cloud.sun.fill", description: "微软企业云计算全球骨干"),
        ProbeSite(id: "site-fastly", name: "Fastly CDN", domain: "fastly.com", port: 443, category: "网络基础设施", icon: "network", description: "边缘计算低延迟分发网"),
        ProbeSite(id: "site-akamai", name: "Akamai Edge", domain: "akamai.com", port: 443, category: "网络基础设施", icon: "shield.lefthalf.filled", description: "全球顶级 CDN 与安全防护"),
        ProbeSite(id: "site-hetzner", name: "Hetzner Cloud", domain: "hetzner.com", port: 443, category: "网络基础设施", icon: "server.rack", description: "欧洲高性价比云服务器"),
        ProbeSite(id: "site-vultr", name: "Vultr Tokyo", domain: "vultr.com", port: 443, category: "网络基础设施", icon: "cpu.fill", description: "亚太东京低延迟虚拟计算"),
        ProbeSite(id: "site-linode", name: "Linode SG", domain: "linode.com", port: 443, category: "网络基础设施", icon: "desktopcomputer", description: "新加坡云计算数据中心"),
        // 社交媒体与国际流媒体
        ProbeSite(id: "site-reddit", name: "Reddit", domain: "reddit.com", port: 443, category: "国际社交", icon: "person.2.fill", description: "全球话题与极客讨论社区"),
        ProbeSite(id: "site-bluesky", name: "Bluesky Social", domain: "bsky.app", port: 443, category: "国际社交", icon: "cloud.moon.fill", description: "去中心化社交网络协议"),
        ProbeSite(id: "site-twitch", name: "Twitch", domain: "twitch.tv", port: 443, category: "国际流媒体", icon: "tv.fill", description: "游戏与全球高码率互动直播"),
        ProbeSite(id: "site-disney", name: "Disney+", domain: "disneyplus.com", port: 443, category: "国际流媒体", icon: "star.fill", description: "高画质影视流媒体平台"),
        // 国内高频直连
        ProbeSite(id: "site-weibo", name: "新浪微博", domain: "weibo.com", port: 443, category: "国内直连", icon: "bubble.left.and.exclamationmark.bubble.right.fill", description: "国内实时公共资讯平台"),
        ProbeSite(id: "site-zhihu", name: "知乎社区", domain: "zhihu.com", port: 443, category: "国内直连", icon: "questionmark.bubble.fill", description: "中文问答与知识沉淀网络"),
        ProbeSite(id: "site-taobao", name: "淘宝网网关", domain: "taobao.com", port: 443, category: "国内直连", icon: "cart.fill", description: "国内高并发核心交易网络"),
        ProbeSite(id: "site-jd", name: "京东零售", domain: "jd.com", port: 443, category: "国内直连", icon: "cart.badge.plus", description: "自营电商物流调度中心"),
        ProbeSite(id: "site-netease-music", name: "网易云音乐", domain: "music.163.com", port: 443, category: "国内直连", icon: "music.note", description: "云音乐核心流媒体与版权服务"),
        // 国际技术社区与前沿生态
        ProbeSite(id: "site-stackoverflow", name: "Stack Overflow", domain: "stackoverflow.com", port: 443, category: "开发平台", icon: "square.stack.3d.up.fill", description: "全球程序员问答互助社区"),
        ProbeSite(id: "site-medium", name: "Medium", domain: "medium.com", port: 443, category: "国际媒体", icon: "newspaper.fill", description: "深度技术与商业洞察博客"),
        ProbeSite(id: "site-substack", name: "Substack", domain: "substack.com", port: 443, category: "国际媒体", icon: "envelope.open.fill", description: "独立创作者订阅与通讯"),
        ProbeSite(id: "site-notion", name: "Notion API", domain: "api.notion.com", port: 443, category: "开发平台", icon: "doc.text.fill", description: "模块化协同知识库"),
        ProbeSite(id: "site-linear", name: "Linear Cloud", domain: "linear.app", port: 443, category: "开发平台", icon: "checklist", description: "高效率工程项目管理协同"),
        ProbeSite(id: "site-figma", name: "Figma Sync", domain: "figma.com", port: 443, category: "开发平台", icon: "paintbrush.fill", description: "现代协同界面设计云"),
        // 国际常用流媒体与音视频
        ProbeSite(id: "site-prime-video", name: "Amazon Prime", domain: "primevideo.com", port: 443, category: "国际流媒体", icon: "play.circle.fill", description: "亚马逊全球原创影视流媒体"),
        ProbeSite(id: "site-hbo-max", name: "Max (HBO)", domain: "max.com", port: 443, category: "国际流媒体", icon: "tv.and.mediabox.fill", description: "华纳高品质剧集影视中心"),
        ProbeSite(id: "site-apple-music", name: "Apple Music", domain: "music.apple.com", port: 443, category: "国际流媒体", icon: "music.quarternote.3", description: "无损与空间音频流媒体网络"),
        // 网络测速与基准节点
        ProbeSite(id: "site-speedtest", name: "Speedtest Ookla", domain: "speedtest.net", port: 443, category: "网络基础设施", icon: "gauge.with.needle.fill", description: "全球宽带性能基准测试"),
        ProbeSite(id: "site-fast-com", name: "Fast.com (Netflix)", domain: "fast.com", port: 443, category: "网络基础设施", icon: "bolt.fill", description: "全球流媒体专线带宽测试"),
        ProbeSite(id: "site-quad9", name: "Quad9 DNS", domain: "quad9.net", port: 443, category: "网络基础设施", icon: "lock.shield", description: "隐私增强与恶意拦截 Anycast DNS"),
        // 更多校园与学术资源
        ProbeSite(id: "site-arxiv", name: "arXiv 学术预印", domain: "arxiv.org", port: 443, category: "校园内网", icon: "books.vertical.fill", description: "康奈尔全球开放学术预印本文库"),
        ProbeSite(id: "site-nature", name: "Nature 科学期刊", domain: "nature.com", port: 443, category: "校园内网", icon: "leaf.fill", description: "全球顶级学术期刊检索网关"),
        ProbeSite(id: "site-ieeexplore", name: "IEEE Xplore", domain: "ieeexplore.ieee.org", port: 443, category: "校园内网", icon: "graduationcap.circle.fill", description: "电气与计算机学术文献内网通道"),
        // 更多国际前沿 AI 服务
        ProbeSite(id: "site-cohere", name: "Cohere API", domain: "api.cohere.com", port: 443, category: "AI 基础设施", icon: "network.badge.shield.half.filled", description: "企业级多语言嵌入与重排模型"),
        ProbeSite(id: "site-together-ai", name: "Together.ai", domain: "api.together.xyz", port: 443, category: "AI 基础设施", icon: "cpu", description: "开源大语言模型分布式推理云"),
        ProbeSite(id: "site-replicate", name: "Replicate Cloud", domain: "replicate.com", port: 443, category: "AI 基础设施", icon: "square.dashed", description: "云端开箱即用开源生成式 AI"),
        // 关键开发者工具
        ProbeSite(id: "site-pypi", name: "PyPI Python 仓库", domain: "pypi.org", port: 443, category: "开发平台", icon: "shippingbox", description: "Python 官方包管理索引"),
        ProbeSite(id: "site-crates", name: "Rust Crates.io", domain: "crates.io", port: 443, category: "开发平台", icon: "gearshape.2.fill", description: "Rust 官方包镜像中心"),
        ProbeSite(id: "site-brew", name: "Homebrew API", domain: "formulae.brew.sh", port: 443, category: "开发平台", icon: "mug.fill", description: "macOS 核心包管理器清单"),
        // 常用社交与资讯
        ProbeSite(id: "site-threads", name: "Meta Threads", domain: "threads.net", port: 443, category: "国际社交", icon: "at", description: "Instagram 文本社交网络"),
        ProbeSite(id: "site-whatsapp", name: "WhatsApp Web", domain: "web.whatsapp.com", port: 443, category: "国际社交", icon: "phone.bubble.fill", description: "端到端加密跨国通讯网络"),
        ProbeSite(id: "site-bloomberg", name: "Bloomberg News", domain: "bloomberg.com", port: 443, category: "国际媒体", icon: "chart.line.uptrend.xyaxis", description: "全球实时金融与商业资讯"),
        ProbeSite(id: "site-reuters", name: "Reuters Wire", domain: "reuters.com", port: 443, category: "国际媒体", icon: "globe.americas.fill", description: "路透社国际突发新闻网关"),
        ProbeSite(id: "site-wsj", name: "Wall Street Journal", domain: "wsj.com", port: 443, category: "国际媒体", icon: "newspaper", description: "华尔街日报实时要闻")
    ]

    public init() {}

    public func getVersion() async throws -> VersionInfo {
        return VersionInfo(version: "2.4.0-ios-release", os: "darwin", arch: "arm64", compiler: "rustc 1.88.0")
    }

    public func getStatus() async throws -> SystemStatus {
        let uptime = Int(Date().timeIntervalSince(startTimestamp))
        let virtualInterfaces = [
            VirtualInterfaceItem(
                name: "Tailscale Mesh",
                type: .tailscale,
                ipv4: "100.86.32.14",
                ipv6: "fd7a:115c:a1e0:ab12::3214",
                subnetMask: "100.64.0.0/10",
                descriptionText: "Tailnet 设备全局唯一 Magic IP，用于跨网穿透、SSH 与局域网服务互访",
                isPrimaryMesh: true
            ),
            VirtualInterfaceItem(
                name: "Tokyo-WG-01",
                type: .underlay,
                ipv4: "10.14.0.5",
                ipv6: nil,
                subnetMask: "10.14.0.0/24",
                descriptionText: "当前活动出站节点在远端 VPN 协议中分配的隧道内网地址",
                isPrimaryMesh: false
            ),
            VirtualInterfaceItem(
                name: "iOS 系统网卡 (utun)",
                type: .utun,
                ipv4: "10.201.0.2",
                ipv6: nil,
                subnetMask: "255.255.255.0",
                descriptionText: "iOS NetworkExtension 唯一分配的系统虚拟槽位，负责将系统出站流量转入 Panto",
                isPrimaryMesh: false
            )
        ]

        return SystemStatus(
            running: isRunning,
            uptimeSeconds: uptime,
            mixedPort: 9090,
            mode: currentMode.rawValue,
            globalTarget: globalTarget,
            activeEndpoints: 14,
            activeGroups: groups.count,
            activeRules: 128,
            assignedIp: "10.201.0.2",
            virtualInterfaces: virtualInterfaces
        )
    }

    public func getMode() async throws -> ModeInfo {
        return ModeInfo(mode: currentMode, globalExit: globalTarget)
    }

    public func setMode(_ mode: TunnelMode, globalExit: String?) async throws -> ModeInfo {
        self.currentMode = mode
        self.globalTarget = globalExit
        return ModeInfo(mode: mode, globalExit: globalExit)
    }

    public func getTopology() async throws -> TopologyData {
        return TopologyData(nodes: topologyNodes)
    }

    public func getGroups() async throws -> GroupsData {
        return GroupsData(groups: groups)
    }

    public func selectGroupMember(groupId: String, memberId: String) async throws -> GroupItem {
        guard let idx = groups.firstIndex(where: { $0.id == groupId }) else {
            throw NSError(domain: "org.panto.mock", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
        }
        let updated = GroupItem(
            id: groups[idx].id,
            kind: groups[idx].kind,
            members: groups[idx].members,
            current: memberId,
            delays: groups[idx].delays
        )
        groups[idx] = updated
        return updated
    }

    public func testGroupDelay(groupId: String, url: String?, timeoutMs: Int?) async throws -> [String: Int] {
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms 模拟测速
        guard let idx = groups.firstIndex(where: { $0.id == groupId }) else {
            return [:]
        }
        var newDelays: [String: Int] = [:]
        for m in groups[idx].members {
            if m == "DIRECT" {
                newDelays[m] = Int.random(in: 4...12)
            } else {
                newDelays[m] = Int.random(in: 25...160)
            }
        }
        let updated = GroupItem(
            id: groups[idx].id,
            kind: groups[idx].kind,
            members: groups[idx].members,
            current: groups[idx].current,
            delays: newDelays
        )
        groups[idx] = updated
        return newDelays
    }

    public func getTraffic() async throws -> TrafficStats {
        let baseUp = Int64.random(in: 80_000...450_000)
        let baseDown = Int64.random(in: 400_000...3_800_000)
        return TrafficStats(
            upBytes: 1024 * 1024 * 142 + baseUp,
            downBytes: 1024 * 1024 * 892 + baseDown,
            upRateBps: baseUp,
            downRateBps: baseDown
        )
    }

    public func getTailscaleExitNodes() async throws -> [TailscaleExitNodeItem] {
        return [
            TailscaleExitNodeItem(id: "node-1", hostname: "tokyo-exit-node", dnsName: "tokyo-exit.tailnet.ts.net", ips: ["100.64.0.2"], online: true, selected: true),
            TailscaleExitNodeItem(id: "node-2", hostname: "us-west-exit", dnsName: "us-west.tailnet.ts.net", ips: ["100.64.0.3"], online: true, selected: false)
        ]
    }

    public func setTailscaleExitNode(nodeId: String) async throws -> String {
        return nodeId
    }

    public func getMagicIPPending() async throws -> [MagicIPConflictItem] {
        return magicConflicts
    }

    public func getMagicIPChoices() async throws -> [MagicIPChoiceItem] {
        return magicChoices
    }

    public func decideMagicIP(ip: String, endpoint: String, remember: Bool) async throws -> Bool {
        magicConflicts.removeAll(where: { $0.ip == ip })
        if remember {
            magicChoices.append(MagicIPChoiceItem(ip: ip, endpoint: endpoint, peerHostname: endpoint, remember: true, updatedAt: "2026-09-19T11:50:00Z"))
        }
        return true
    }

    public func getRules() async throws -> [RuleItem] {
        return rules
    }

    public func matchRule(domain: String?, ip: String?, port: Int?, network: String?) async throws -> RuleMatchResult {
        if let domain = domain {
            if domain.contains("apple") || domain.contains("icloud") {
                return RuleMatchResult(rule: "DOMAIN-SUFFIX,apple.com,DIRECT", target: "DIRECT", matched: true)
            }
            if domain.contains("google") || domain.contains("github") || domain.contains("openai") {
                return RuleMatchResult(rule: "DOMAIN-SUFFIX,\(domain),⚡ 节点选择 (Proxy)", target: "⚡ 节点选择 (Proxy)", matched: true)
            }
        }
        if let ip = ip, ip.hasPrefix("100.") {
            return RuleMatchResult(rule: "IP-CIDR,100.64.0.0/10,🌐 Tailscale 网格", target: "🌐 Tailscale 网格", matched: true)
        }
        return RuleMatchResult(rule: "MATCH,DIRECT", target: "DIRECT", matched: true)
    }

    public func getObservationConsents() async throws -> [ObservationConsentItem] {
        return observationConsents
    }

    public func decideObservationConsent(endpointId: String, allow: Bool, remember: Bool) async throws -> Bool {
        observationConsents.removeAll(where: { $0.endpointId == endpointId })
        return true
    }

    public func getProbeSites() async throws -> [ProbeSite] {
        return probeSites
    }

    public func testProbeSites(siteId: String?) async throws -> [ProbeResultItem] {
        var results: [ProbeResultItem] = []
        let targets = siteId != nil ? probeSites.filter { $0.id == siteId } : probeSites
        for site in targets {
            let isDirect = site.category.contains("国内")
            results.append(
                ProbeResultItem(
                    id: site.id,
                    domain: site.domain,
                    ruleTarget: isDirect ? "DIRECT" : "⚡ 节点选择 (Proxy)",
                    selectedEndpoint: isDirect ? "DIRECT" : "🇸🇬 新加坡 01",
                    chain: isDirect ? ["DIRECT"] : ["DIRECT", "🇸🇬 新加坡 01"],
                    latencyMs: isDirect ? Int.random(in: 10...30) : Int.random(in: 40...120),
                    status: "200 OK",
                    error: nil
                )
            )
        }
        return results
    }

    public func streamProbeSites() -> AsyncStream<ProbeResultItem> {
        let sites = self.probeSites
        return AsyncStream { continuation in
            Task {
                for (_, site) in sites.enumerated() {
                    try? await Task.sleep(nanoseconds: 40_000_000) // 40ms 逐个高速流式返回
                    let isDirect = site.category.contains("国内") || site.category.contains("校园")
                    let isFailed = (site.id == "site-telegram" || site.id == "site-hetzner" || site.id == "site-wsj") // 模拟故障红格节点
                    let isTimeout = (site.id == "site-netflix")
                    
                    let item: ProbeResultItem
                    if isFailed {
                        item = ProbeResultItem(
                            id: site.id,
                            domain: site.domain,
                            ruleTarget: "⚡ 节点选择 (Proxy)",
                            selectedEndpoint: "🇸🇬 新加坡 01",
                            chain: ["DIRECT", "🇸🇬 新加坡 01"],
                            latencyMs: -1,
                            status: site.id == "site-hetzner" ? "502 Bad Gateway" : "504 Gateway Timeout",
                            error: site.id == "site-hetzner" ? "欧洲边缘路由不可达 (Host Unreachable)" : "连接超时 (2500ms)"
                        )
                    } else if isTimeout {
                        item = ProbeResultItem(
                            id: site.id,
                            domain: site.domain,
                            ruleTarget: "⚡ 节点选择 (Proxy)",
                            selectedEndpoint: "🇸🇬 新加坡 01",
                            chain: ["DIRECT", "🇸🇬 新加坡 01"],
                            latencyMs: 380,
                            status: "403 Forbidden",
                            error: "地区限制解锁失败"
                        )
                    } else {
                        item = ProbeResultItem(
                            id: site.id,
                            domain: site.domain,
                            ruleTarget: isDirect ? "DIRECT" : "⚡ 节点选择 (Proxy)",
                            selectedEndpoint: isDirect ? "DIRECT" : "🇸🇬 新加坡 01",
                            chain: isDirect ? ["DIRECT"] : ["DIRECT", "🇸🇬 新加坡 01"],
                            latencyMs: isDirect ? Int.random(in: 12...35) : Int.random(in: 45...140),
                            status: "200 OK",
                            error: nil
                        )
                    }
                    continuation.yield(item)
                }
                continuation.finish()
            }
        }
    }
}

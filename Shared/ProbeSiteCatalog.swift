import Foundation

/// ProbeSiteCatalog 提供全球测速与网络健康度矩阵的基准站点目录。
/// 覆盖开发平台、网络基础设施、前沿 AI、国际媒体、校园与企业内网、国内直连等多个核心维度。
public enum ProbeSiteCatalog {
    public static let defaultSites: [ProbeSite] = [
        // 开发者与代码平台
        ProbeSite(id: "site-github", name: "GitHub", domain: "github.com", port: 443, category: "开发平台", icon: "chevron.left.forwardslash.chevron.right", description: "全球开发者代码协作平台"),
        ProbeSite(id: "site-npm", name: "NPM Registry", domain: "registry.npmjs.org", port: 443, category: "开发平台", icon: "shippingbox.fill", description: "Node.js 官方依赖镜像"),
        ProbeSite(id: "site-docker", name: "Docker Hub", domain: "hub.docker.com", port: 443, category: "开发平台", icon: "cube.box.fill", description: "全球容器镜像中心"),
        ProbeSite(id: "site-huggingface", name: "Hugging Face", domain: "huggingface.co", port: 443, category: "开发平台", icon: "face.smiling.fill", description: "开源 AI 模型与数据集社区"),
        ProbeSite(id: "site-gitlab", name: "GitLab", domain: "gitlab.com", port: 443, category: "开发平台", icon: "terminal.fill", description: "企业级代码托管与 CI/CD"),
        ProbeSite(id: "site-grafana", name: "Grafana Cloud", domain: "grafana.net", port: 443, category: "开发平台", icon: "chart.xyaxis.line", description: "分布式云原生观测平台"),
        ProbeSite(id: "site-supabase", name: "Supabase", domain: "supabase.com", port: 443, category: "开发平台", icon: "bolt.horizontal.fill", description: "开源 Firebase 替代架构"),
        ProbeSite(id: "site-sentry", name: "Sentry.io", domain: "sentry.io", port: 443, category: "开发平台", icon: "ant.fill", description: "应用异常性能监控平台"),
        ProbeSite(id: "site-redis", name: "Redis Cloud", domain: "redislabs.com", port: 443, category: "开发平台", icon: "cylinder.split.1x2.fill", description: "全球分布式内存缓存网络"),
        ProbeSite(id: "site-postman", name: "Postman API", domain: "postman.com", port: 443, category: "开发平台", icon: "arrow.up.right.video.fill", description: "API 协同与测试中心"),
        ProbeSite(id: "site-stackoverflow", name: "Stack Overflow", domain: "stackoverflow.com", port: 443, category: "开发平台", icon: "square.stack.3d.up.fill", description: "全球程序员问答互助社区"),
        ProbeSite(id: "site-notion", name: "Notion API", domain: "api.notion.com", port: 443, category: "开发平台", icon: "doc.text.fill", description: "模块化协同知识库"),
        ProbeSite(id: "site-linear", name: "Linear Cloud", domain: "linear.app", port: 443, category: "开发平台", icon: "checklist", description: "高效率工程项目管理协同"),
        ProbeSite(id: "site-figma", name: "Figma Sync", domain: "figma.com", port: 443, category: "开发平台", icon: "paintbrush.fill", description: "现代协同界面设计云"),
        ProbeSite(id: "site-pypi", name: "PyPI Python 仓库", domain: "pypi.org", port: 443, category: "开发平台", icon: "shippingbox", description: "Python 官方包管理索引"),
        ProbeSite(id: "site-crates", name: "Rust Crates.io", domain: "crates.io", port: 443, category: "开发平台", icon: "gearshape.2.fill", description: "Rust 官方包镜像中心"),
        ProbeSite(id: "site-brew", name: "Homebrew API", domain: "formulae.brew.sh", port: 443, category: "开发平台", icon: "mug.fill", description: "macOS 核心包管理器清单"),

        // 国际搜索与网络基础设施
        ProbeSite(id: "site-google", name: "Google", domain: "google.com", port: 443, category: "国际搜索", icon: "globe", description: "国际搜索引擎与基础设施"),
        ProbeSite(id: "site-cloudflare", name: "Cloudflare 1.1.1.1", domain: "1.1.1.1", port: 443, category: "网络基础设施", icon: "bolt.shield.fill", description: "全球低延迟 Anycast 边缘网络"),
        ProbeSite(id: "site-aws", name: "AWS Global", domain: "aws.amazon.com", port: 443, category: "网络基础设施", icon: "server.rack", description: "亚马逊全球云计算骨干网"),
        ProbeSite(id: "site-vercel", name: "Vercel Edge", domain: "vercel.com", port: 443, category: "网络基础设施", icon: "triangle.fill", description: "现代 Web 全球边缘网络"),
        ProbeSite(id: "site-cloud-ali", name: "阿里云国际站", domain: "alibabacloud.com", port: 443, category: "网络基础设施", icon: "cloud.fill", description: "亚太边缘跨境专线网络"),
        ProbeSite(id: "site-azure", name: "Azure Global", domain: "azure.microsoft.com", port: 443, category: "网络基础设施", icon: "cloud.sun.fill", description: "微软企业云计算全球骨干"),
        ProbeSite(id: "site-fastly", name: "Fastly CDN", domain: "fastly.com", port: 443, category: "网络基础设施", icon: "network", description: "边缘计算低延迟分发网"),
        ProbeSite(id: "site-akamai", name: "Akamai Edge", domain: "akamai.com", port: 443, category: "网络基础设施", icon: "shield.lefthalf.filled", description: "全球顶级 CDN 与安全防护"),
        ProbeSite(id: "site-hetzner", name: "Hetzner Cloud", domain: "hetzner.com", port: 443, category: "网络基础设施", icon: "server.rack", description: "欧洲高性价比云服务器"),
        ProbeSite(id: "site-vultr", name: "Vultr Tokyo", domain: "vultr.com", port: 443, category: "网络基础设施", icon: "cpu.fill", description: "亚太东京低延迟虚拟计算"),
        ProbeSite(id: "site-linode", name: "Linode SG", domain: "linode.com", port: 443, category: "网络基础设施", icon: "desktopcomputer", description: "新加坡云计算数据中心"),
        ProbeSite(id: "site-speedtest", name: "Speedtest Ookla", domain: "speedtest.net", port: 443, category: "网络基础设施", icon: "gauge.with.needle.fill", description: "全球宽带性能基准测试"),
        ProbeSite(id: "site-fast-com", name: "Fast.com (Netflix)", domain: "fast.com", port: 443, category: "网络基础设施", icon: "bolt.fill", description: "全球流媒体专线带宽测试"),
        ProbeSite(id: "site-quad9", name: "Quad9 DNS", domain: "quad9.net", port: 443, category: "网络基础设施", icon: "lock.shield", description: "隐私增强与恶意拦截 Anycast DNS"),

        // 大语言模型与 AI 平台
        ProbeSite(id: "site-openai", name: "OpenAI API", domain: "api.openai.com", port: 443, category: "AI 基础设施", icon: "sparkles", description: "ChatGPT 与 GPT-4o 核心网关"),
        ProbeSite(id: "site-claude", name: "Claude AI", domain: "claude.ai", port: 443, category: "AI 基础设施", icon: "brain.head.profile", description: "Anthropic 智能对话系统"),
        ProbeSite(id: "site-gemini", name: "Google Gemini", domain: "gemini.google.com", port: 443, category: "AI 基础设施", icon: "wand.and.stars", description: "多模态大模型推理接口"),
        ProbeSite(id: "site-deepseek", name: "DeepSeek API", domain: "api.deepseek.com", port: 443, category: "AI 基础设施", icon: "sparkle", description: "推理与代码生成大模型"),
        ProbeSite(id: "site-perplexity", name: "Perplexity AI", domain: "perplexity.ai", port: 443, category: "AI 基础设施", icon: "brain", description: "对话式实时搜索智能体"),
        ProbeSite(id: "site-groq", name: "Groq LPU", domain: "groq.com", port: 443, category: "AI 基础设施", icon: "bolt.fill", description: "超高速硬件加速大模型推理"),
        ProbeSite(id: "site-mistral", name: "Mistral AI", domain: "mistral.ai", port: 443, category: "AI 基础设施", icon: "wind", description: "开源与商业模型前沿网关"),
        ProbeSite(id: "site-cohere", name: "Cohere API", domain: "api.cohere.com", port: 443, category: "AI 基础设施", icon: "network.badge.shield.half.filled", description: "企业级多语言嵌入与重排模型"),
        ProbeSite(id: "site-together-ai", name: "Together.ai", domain: "api.together.xyz", port: 443, category: "AI 基础设施", icon: "cpu", description: "开源大语言模型分布式推理云"),
        ProbeSite(id: "site-replicate", name: "Replicate Cloud", domain: "replicate.com", port: 443, category: "AI 基础设施", icon: "square.dashed", description: "云端开箱即用开源生成式 AI"),

        // 跨国社交与流媒体
        ProbeSite(id: "site-x", name: "X (Twitter)", domain: "x.com", port: 443, category: "国际社交", icon: "bubble.left.and.bubble.right.fill", description: "实时动态社交平台"),
        ProbeSite(id: "site-telegram", name: "Telegram Web", domain: "web.telegram.org", port: 443, category: "国际社交", icon: "paperplane.fill", description: "加密即时通讯网络"),
        ProbeSite(id: "site-discord", name: "Discord", domain: "discord.com", port: 443, category: "国际社交", icon: "bubble.middle.bottom.fill", description: "低延迟语音与社区网络"),
        ProbeSite(id: "site-reddit", name: "Reddit", domain: "reddit.com", port: 443, category: "国际社交", icon: "person.2.fill", description: "全球话题与极客讨论社区"),
        ProbeSite(id: "site-bluesky", name: "Bluesky Social", domain: "bsky.app", port: 443, category: "国际社交", icon: "cloud.moon.fill", description: "去中心化社交网络协议"),
        ProbeSite(id: "site-threads", name: "Meta Threads", domain: "threads.net", port: 443, category: "国际社交", icon: "at", description: "Instagram 文本社交网络"),
        ProbeSite(id: "site-whatsapp", name: "WhatsApp Web", domain: "web.whatsapp.com", port: 443, category: "国际社交", icon: "phone.bubble.fill", description: "端到端加密跨国通讯网络"),
        ProbeSite(id: "site-wikipedia", name: "Wikipedia", domain: "wikipedia.org", port: 443, category: "国际媒体", icon: "book.fill", description: "全球多语言自由百科全书"),
        ProbeSite(id: "site-youtube", name: "YouTube", domain: "youtube.com", port: 443, category: "国际流媒体", icon: "play.rectangle.fill", description: "国际高码率视频流媒体"),
        ProbeSite(id: "site-netflix", name: "Netflix", domain: "netflix.com", port: 443, category: "国际流媒体", icon: "film.fill", description: "全球 4K HDR 视频流媒体"),
        ProbeSite(id: "site-spotify", name: "Spotify", domain: "spotify.com", port: 443, category: "国际流媒体", icon: "waveform", description: "全球高品质音频流媒体"),
        ProbeSite(id: "site-steam", name: "Steam Store", domain: "steampowered.com", port: 443, category: "国际媒体", icon: "gamecontroller.fill", description: "全球数字游戏分发与 CDN"),
        ProbeSite(id: "site-twitch", name: "Twitch", domain: "twitch.tv", port: 443, category: "国际流媒体", icon: "tv.fill", description: "游戏与全球高码率互动直播"),
        ProbeSite(id: "site-disney", name: "Disney+", domain: "disneyplus.com", port: 443, category: "国际流媒体", icon: "star.fill", description: "高画质影视流媒体平台"),
        ProbeSite(id: "site-prime-video", name: "Amazon Prime", domain: "primevideo.com", port: 443, category: "国际流媒体", icon: "play.circle.fill", description: "亚马逊全球原创影视流媒体"),
        ProbeSite(id: "site-hbo-max", name: "Max (HBO)", domain: "max.com", port: 443, category: "国际流媒体", icon: "tv.and.mediabox.fill", description: "华纳高品质剧集影视中心"),
        ProbeSite(id: "site-apple-music", name: "Apple Music", domain: "music.apple.com", port: 443, category: "国际流媒体", icon: "music.quarternote.3", description: "无损与空间音频流媒体网络"),
        ProbeSite(id: "site-medium", name: "Medium", domain: "medium.com", port: 443, category: "国际媒体", icon: "newspaper.fill", description: "深度技术与商业洞察博客"),
        ProbeSite(id: "site-substack", name: "Substack", domain: "substack.com", port: 443, category: "国际媒体", icon: "envelope.open.fill", description: "独立创作者订阅与通讯"),
        ProbeSite(id: "site-bloomberg", name: "Bloomberg News", domain: "bloomberg.com", port: 443, category: "国际媒体", icon: "chart.line.uptrend.xyaxis", description: "全球实时金融与商业资讯"),
        ProbeSite(id: "site-reuters", name: "Reuters Wire", domain: "reuters.com", port: 443, category: "国际媒体", icon: "globe.americas.fill", description: "路透社国际突发新闻网关"),
        ProbeSite(id: "site-wsj", name: "Wall Street Journal", domain: "wsj.com", port: 443, category: "国际媒体", icon: "newspaper", description: "华尔街日报实时要闻"),

        // 系统生态
        ProbeSite(id: "site-apple", name: "Apple Services", domain: "apple.com", port: 443, category: "系统生态", icon: "apple.logo", description: "iCloud 与 CDN 基础设施"),
        ProbeSite(id: "site-apple-testflight", name: "TestFlight CDN", domain: "testflight.apple.com", port: 443, category: "系统生态", icon: "airplane.circle.fill", description: "iOS 测试应用分发 CDN"),
        ProbeSite(id: "site-raycast", name: "Raycast Store", domain: "raycast.com", port: 443, category: "系统生态", icon: "command", description: "快捷指令与扩展市场"),

        // 校园内网与学术资源
        ProbeSite(id: "site-campus-portal", name: "校园办事大厅", domain: "portal.edu.cn", port: 443, category: "校园内网", icon: "building.columns.fill", description: "校园高可用统一身份认证"),
        ProbeSite(id: "site-campus-jw", name: "校园教务系统", domain: "jwxt.edu.cn", port: 443, category: "校园内网", icon: "graduationcap.fill", description: "教务内网选课与选拔通道"),
        ProbeSite(id: "site-campus-mirror", name: "高校开源镜像站", domain: "mirrors.tuna.tsinghua.edu.cn", port: 443, category: "校园内网", icon: "arrow.down.doc.fill", description: "校园千兆本地镜像加速"),
        ProbeSite(id: "site-arxiv", name: "arXiv 学术预印", domain: "arxiv.org", port: 443, category: "校园内网", icon: "books.vertical.fill", description: "康奈尔全球开放学术预印本文库"),
        ProbeSite(id: "site-nature", name: "Nature 科学期刊", domain: "nature.com", port: 443, category: "校园内网", icon: "leaf.fill", description: "全球顶级学术期刊检索网关"),
        ProbeSite(id: "site-ieeexplore", name: "IEEE Xplore", domain: "ieeexplore.ieee.org", port: 443, category: "校园内网", icon: "graduationcap.circle.fill", description: "电气与计算机学术文献内网通道"),

        // 国内高频直连服务
        ProbeSite(id: "site-bilibili", name: "哔哩哔哩", domain: "bilibili.com", port: 443, category: "国内直连", icon: "play.tv.fill", description: "国内主站直连流媒体"),
        ProbeSite(id: "site-baidu", name: "百度搜索", domain: "baidu.com", port: 443, category: "国内直连", icon: "magnifyingglass", description: "国内基础搜索引擎"),
        ProbeSite(id: "site-qq", name: "微信互联中心", domain: "qq.com", port: 443, category: "国内直连", icon: "message.fill", description: "腾讯即时通信直连网关"),
        ProbeSite(id: "site-weibo", name: "新浪微博", domain: "weibo.com", port: 443, category: "国内直连", icon: "bubble.left.and.exclamationmark.bubble.right.fill", description: "国内实时公共资讯平台"),
        ProbeSite(id: "site-zhihu", name: "知乎社区", domain: "zhihu.com", port: 443, category: "国内直连", icon: "questionmark.bubble.fill", description: "中文问答与知识沉淀网络"),
        ProbeSite(id: "site-taobao", name: "淘宝网网关", domain: "taobao.com", port: 443, category: "国内直连", icon: "cart.fill", description: "国内高并发核心交易网络"),
        ProbeSite(id: "site-jd", name: "京东零售", domain: "jd.com", port: 443, category: "国内直连", icon: "cart.badge.plus", description: "自营电商物流调度中心"),
        ProbeSite(id: "site-netease-music", name: "网易云音乐", domain: "music.163.com", port: 443, category: "国内直连", icon: "music.note", description: "云音乐核心流媒体与版权服务")
    ]
}

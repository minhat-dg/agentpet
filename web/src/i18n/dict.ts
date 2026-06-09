// AgentPet web i18n dictionary. Keyed by the ENGLISH source string (so the
// client engine can both translate to vi/zh and restore English on switch-back).
// The engine auto-translates any text node / [data-i18n] element / data-i18n-*
// attribute whose English text matches a key here, across every page.
//
// Add strings page by page. Keep keys = the exact English text as rendered.
export type Lang = "en" | "vi" | "zh";
export const LANGS: Lang[] = ["en", "vi", "zh"];

export const DICT: Record<"vi" | "zh", Record<string, string>> = {
  vi: {
    // nav + footer chrome
    "Gallery": "Thư viện", "Collections": "Bộ sưu tập", "Leaderboard": "Bảng xếp hạng",
    "Requests": "Yêu cầu", "Make": "Tạo", "Integrations": "Tích hợp", "Creators": "Người tạo",
    "Contributors": "Người đóng góp", "Docs": "Tài liệu", "Sign in": "Đăng nhập",
    "Sign out": "Đăng xuất", "Pet admin": "Quản trị pet",
    "Get the app": "Tải ứng dụng", "Explore": "Khám phá", "Community": "Cộng đồng",
    "Get started": "Bắt đầu", "Make a pet": "Tạo thú cưng", "Submit a pet": "Gửi thú cưng",
    "Install guide": "Hướng dẫn cài", "Legal & takedown": "Pháp lý & gỡ bỏ",
    "Download AgentPet and pick a companion.": "Tải AgentPet và chọn một người bạn.",
  },
  zh: {
    "Gallery": "图库", "Collections": "合集", "Leaderboard": "排行榜",
    "Requests": "请求", "Make": "制作", "Integrations": "集成", "Creators": "创作者",
    "Contributors": "贡献者", "Docs": "文档", "Sign in": "登录",
    "Sign out": "退出登录", "Pet admin": "宠物管理",
    "Get the app": "获取应用", "Explore": "探索", "Community": "社区",
    "Get started": "开始使用", "Make a pet": "制作宠物", "Submit a pet": "提交宠物",
    "Install guide": "安装指南", "Legal & takedown": "法律与下架",
    "Download AgentPet and pick a companion.": "下载 AgentPet，挑一只伙伴。",
  },
};

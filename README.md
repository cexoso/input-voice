# InputVoice

macOS 菜单栏语音输入工具。按住 Fn 键说话，松开后自动将语音识别结果粘贴到当前光标位置。

**系统要求：** macOS 14 (Sonoma) 或更高版本

## 安装

### 从源码构建

需要安装 Xcode Command Line Tools：

```bash
xcode-select --install
```

克隆仓库并安装：

```bash
git clone https://github.com/yourname/input-voice.git
cd input-voice
make install
```

安装完成后在 `/Applications/InputVoice.app` 中找到该应用，双击启动。

## 首次使用

启动后菜单栏会出现麦克风图标。首次运行需要授予以下三项权限，缺少任何一项都会导致功能异常：

**1. 辅助功能（必须）**

用于监听 Fn 键和模拟键盘输入。

系统设置 → 隐私与安全性 → 辅助功能 → 添加 InputVoice 并勾选。

**2. 麦克风（必须）**

系统设置 → 隐私与安全性 → 麦克风 → 打开 InputVoice 开关。

**3. 语音识别（必须）**

系统设置 → 隐私与安全性 → 语音识别 → 打开 InputVoice 开关。

> 授权后如果仍然无响应，完全退出并重新启动 InputVoice。

## 使用方法

1. 将光标点到任意输入框
2. **按住 Fn 键**开始录音，屏幕中央会出现浮动胶囊窗口并实时显示识别文字
3. **松开 Fn 键**停止录音，识别结果自动粘贴到光标位置

## 菜单栏设置

点击状态栏麦克风图标打开菜单：

**Language** — 切换识别语言，支持：
- 简体中文（默认）
- 繁体中文
- 英语
- 日语
- 韩语

**LLM Refinement** — 使用 AI 对识别结果进行纠错，修正同音字错误（例如"配森"→ Python，"杰森"→ JSON）。

## LLM 纠错配置

语音识别对技术词汇的准确率有限，开启 LLM 纠错可以显著改善识别质量。

1. 菜单栏 → **LLM Refinement → Settings...**
2. 填写以下信息：
   - **API Base URL**：API 服务地址
   - **API Key**：你的 API 密钥
   - **Model**：模型名称
3. 点击 **Test** 验证连接，点击 **Save** 保存
4. 回到菜单勾选 **Enable LLM Refinement**

支持任何 OpenAI 兼容的 API 服务，例如：

| 服务 | API Base URL | 推荐模型 |
|------|-------------|---------|
| OpenAI | `https://api.openai.com/v1` | `gpt-4.1-mini` |
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` |
| Moonshot | `https://api.moonshot.cn/v1` | `moonshot-v1-8k` |
| 通义千问 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-turbo` |

## 构建命令

```bash
make build    # 仅构建 .app
make install  # 构建并安装到 /Applications
make clean    # 清理构建产物
```

使用真实开发者证书签名：

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name" make install
```

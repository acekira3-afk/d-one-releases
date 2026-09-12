# D-one ver2.32 preview 源码

这里是公开测试版 DMG 对应的可构建源码。主程序使用 Objective-C、Cocoa 与 WebKit；窗口界面位于 `web/`。不包含本机便签、聊天记录、API Key、已构建的 `.app` 或 DMG。

在 macOS 14+、已安装 Command Line Tools 的 Mac 上运行 `./build-app.sh` 可生成临时签名的 `D-one.app`；运行 `./build-dmg.sh` 可生成安装映像。构建脚本会复制 `web/assets/` 中实际使用的图像资源。Intel 和 Apple Silicon 均会编入同一应用。

这是个人制作的非官方、非商业预览版。代码暂未选定开源许可证；若希望在其他项目复用，请先与作者确认。初音未来、重音 Teto、亚北音留相关形象和名称的权利归各自权利方所有，图像素材不因源码公开而获得额外授权。本项目与角色权利方及模型服务提供方均无官方关联。

模型面板属于实验功能：用户自行提供 API Key，密钥通过 macOS 钥匙串保存；提问及所选主便签文字会发送给选定的模型提供方，子便签不会发送。请勿把个人密钥贴到 Issue、日志或提交记录中。

---
title: ida pro mcp踩坑
author: Harpyja
date: 2026-03-21
category: Jekyll
tags: [LLM, IDA PRO, Cline, OpenCode]
layout: post
mermaid: true
---
Env: MacOS
其实就是按照[ida-pro-mcp][1]中gui的配置来配置到ida pro中。其中版本最好是9以上的版本。
```shell
1. 在/Application/IDA/Contents/中找到idapyswitch这个文件，执行一下选定python3.11以上的版本
2. pip3 install https://github.com/mrexodia/ida-pro-mcp/archive/refs/heads/main.zip
3. ida-pro-mcp --install

> > ##### 注意
> > 这里会让配置这个mcp是以什么方式进行访问的：http,io,sse. 这里选http就好（io没用过，而且opencode，cline这些客户端每一种配置mcp的方式都不太一样，我一般都是直接配置好端然后让端内的agent帮我配置好。比方说opencode的中转站api都得手动配置url，key和模型id，而不是直接从/model接口自动获取的。cline的mcp配置方式是直接支持界面上配置http协议的mcp的，直接填就可以了（就和openai接口需要带/v1一样，mcp接口需要http://xxx.xxx.xxx.xxx:xxx/mcp,否则是无法接通的））
> {: .block-warning }

```

然后重启IDA，在Plugins里就会出现MCP选项，这时候打开，在终端里就会显示出来开启了mcp：http://127.0.0.1:12345/config.html，这个页面就是配置mcp skills和启用功能的地方。然后就在opencode或者cline中直接对话看ida-pro-mcp中能看到光标在哪 然后顺理成章的开始反平坦化就可以了

[1]:https://github.com/mrexodia/ida-pro-mcp
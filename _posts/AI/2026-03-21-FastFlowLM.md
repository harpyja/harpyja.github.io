---
title: FastFlowLM 部署踩坑
author: Harpyja
date: 2026-03-21
category: Jekyll
tags: [FastFlowLM, NPU, AMD]
layout: post
mermaid: true
---

[FastFlowLM][1]是一款基于AMD NPU的大模型部署框架，其目的是在AMD NPU上以有限资源运行大语言模型，类似GPT-20B，QWEN3-8B等。目前最大的参数规模是GPT-20B的模型

[FastFlowLM-Companion][2]是FastFlowLM的管理框架，其目的是将本地运行的模型映射到http方便外部调用使用

> ##### 配置
> CPU: AMD AI MAX+ 395
> 
> MEM: 128G
> 
> GPU: 8060S
>
> NPU: XDNA2
> 
> 环境: FastFlowLM，FastFlowLM-Companion

#### 下载启动器
> 此处为启动器，官方原版使用huggingface.co+q4nx格式模型，此处下载的只是启动器，需要在官方readme页面查看哪些是官方支持的模型
> >#### 注意
> >官方使用的q4nx模型为已经量化好的模型，与onnx格式有所不同 不直接支持onnx的intel npu大模型格式
>{: .block-warning }
{: .block-warning }

[官方Release][3]
```shell
git clone git@github.com:zai-org/Open-AutoGLM.git
```
> ##### 注意
> 官方使用的vllm环境为非量化版本，模型大小约为20GB，如果算力不够的情况下（PS：8060s性能约为gtx4060）会非常卡顿，所以在此使用GGUF量化版本
> 量化版本链接:[https://hf-mirror.com/enacimie/AutoGLM-Phone-9B-Multilingual-Q4_K_M-GGUF][2]
> >##### 注意
> >LM-Studio中使用多模态模型需要注意：
> > >！！！！视觉模型的gguf是单独的文件！！！！
> >{: .block-danger }
> ，如果缺少[mmproj][3]视觉感知器会导致多模态无法识别图片 
> >具体的显示就是接口报错和在输入图片的时候显示此模型无法处理图片数据
> {: .block-warning }
{: .block-warning }

#### 使用前
> ##### 注意
> android16以上版本需要重新编译ADBKeyboard，推荐使用android15版本运行，并根据main.py的指示进行操作
> 工程地址：[https://github.com/senzhk/ADBKeyBoard][4]
> 下载地址：[https://github.com/senzhk/ADBKeyBoard/blob/master/ADBKeyboard.apk][5]
{: .block-warning }

#### 运行脚本
```shell
python3 main.py --base-url http://127.0.0.1:1234/v1 --model "autoglm-phone-9b"
```

> ##### TIPS
> 如果使用官方的线上模型接口则使用
> ```shell
> python3 main.py --base-url https://open.bigmodel.cn/api/paas/v4 --model "autoglm-phone" --apikey xxxxxxxxxx
> ```
{: .block-tips }

#### AutoGLM main.py 502
> ##### 注意
> 如果你正在使用clash等梯子软件 请看这里：[https://github.com/songquanpeng/one-api/issues/1897][6]
> 
> 梯子问题会导致localhost与192.168.0.0/16地址段被劫持，进而发生curl，postman等接口测试类软件好使而python请求不好使的情况
>
> 这种情况只需要把clash等代理关掉，如果不好使请重启
>
{: .block-danger }

[1]: https://github.com/FastFlowLM/FastFlowLM
[2]: https://github.com/julienM77/Flm-Companion
[3]: https://github.com/FastFlowLM/FastFlowLM/releases
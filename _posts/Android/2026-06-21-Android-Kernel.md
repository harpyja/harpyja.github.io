---
title: Android Kernel代码同步
author: Harpyja
date: 2026-06-21
category: Jekyll
tags: [Kernel, Android]
layout: post
mermaid: true
---

国内目前Kernel代码还得是清华的源 不过截止目前，同步代码需要排队了 而且就我需要的分支而言是存在部分仓库无法同步的现象

类比AOSP同步：[清华AOSP镜像站使用方法][1]
但是Kernel同步有些不同，使用的是https://aosp.tuna.tsinghua.edu.cn/kernel/manifest  
repo资源还是要按照AOSP的方式进行加速：
```shell
export REPO_URL='https://mirrors.tuna.tsinghua.edu.cn/git/git-repo'
```
然后按照自己所需的分支进行下载，这里我使用的是Pixel6进行测试，但是我需要新一点的6.1版本（也就是带GKI的版本）
```shell
repo init -u https://aosp.tuna.tsinghua.edu.cn/kernel/manifest -b android-gs-raviole-6.1-android15-qpr2-beta
```

> ##### 注意
> 这里在init之后需要把.repo中https://android.googlesource.com域名替换成清华的源 也就是https://aosp.tuna.tsinghua.edu.c 再进行同步才会更快一点
{: .block-warning }

然后sync
```shell
repo sync -c --no-tags # 这里是android官方给出的建议，只同步当前分支，且不同步git tags
```

最后会出现5个失败的地方：
```shell
error: Unable to fully sync the tree
error: Downloading network changes failed.
Failing repos (network):
private/devices/google/shusky
private/google-modules/edgetpu/rio
private/google-modules/gps/broadcom/bcm47765
private/google-modules/gxp/zuma
private/google-modules/hdcp/samsung
```

这5个地方需要手动到https://android.googlesource.com/kernel/下使用git clone进行同步 然后再将同步的文件夹按照default.xml中的位置放置到指定位置。比方说：
```shell
<project path="private/devices/google/shusky" name="kernel/devices/google/shusky" groups="partner,shusky" >
就意味着shusky这个文件夹需要放置到private/devices/google 下
```

[1]: https://mirrors.tuna.tsinghua.edu.cn/help/AOSP/

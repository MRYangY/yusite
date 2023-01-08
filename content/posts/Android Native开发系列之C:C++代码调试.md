---
title: "Android Native开发系列之C/C++代码调试"
date: 2023-01-08T11:07:50+08:00
draft: false
tags: ["调试", "Android Native开发"]
categories: ["Android Native开发"]
---



### Android Native开发系列之C/C++代码调试



![](https://raw.githubusercontent.com/MRYangY/blog-img/main/Android%20Native%E5%BC%80%E5%8F%91%E7%B3%BB%E5%88%97%E4%B9%8BC%3AC%2B%2B%E4%BB%A3%E7%A0%81%E8%B0%83%E8%AF%95-%E5%B0%81%E9%9D%A2%E5%9B%BE.jpg)



#### 引言

在做Android native层开发的时候，需要经常调试C/C++代码，相较而言通过打日志的方式太不方便了。有两种方式可以进行底层代码的调试。

1. 利用Android studio自带的Debugger进行调试。
2. 利用LLDB + VSCode进行代码调试。

第一种方式，适合公司内部的开发环境下使用，第二种方式适合在与客户联调时使用。

例如客户使用我们sdk的过程中遇到了问题，因为没法完整模拟客户的使用场景，不好排查问题，那我们这边需要源码断点调式时，可以给客户一个包含debug信息的so，客户集成后，编译一个apk给我们。我们就可以利用这个apk，进行源码调试。



### Android Studio Debugger

先说简单的，拿ndk-sample里的native-codec工程做例子。在需要调试的代码处，打断点，然后直接点debug调试按钮即可。

![](https://raw.githubusercontent.com/MRYangY/blog-img/main/20230107192017.png)



这里需要注意的是Debug Type 需要选择正确的模式。

- Java Only
- Native Only
- Java+Native
- Detect Automatically

更改Debug Type模式的方式：点击 Run->Editor Configurations..  进入如下界面。

![](https://raw.githubusercontent.com/MRYangY/blog-img/main/20230107192813.png)

成功后的效果图：

![](https://raw.githubusercontent.com/MRYangY/blog-img/main/20230107192222.png)



不过，经过我的经验发现，这样做不是很保险，有时候会出现debug失败的情况，会出现找不到so的信息，保险起见的做法是在Run/Debug Configurations页面中，加入Symbol Directories信息，指明so路径。

![](https://raw.githubusercontent.com/MRYangY/blog-img/main/20230107200424.png)

上面的页面可以用快捷键打开：control+option+D(Mac) / Alt+Shift+F9(Windows)



**LLDB Startup Commands** 和 **LLDB Post Attach Commands** 选项可以用到设置LLDB命令，设置的LLDB命令会在对应的时机触发。关于lldb具体有哪些命令，大家可以查询相应文档。

[LLDB Commands](https://lldb.llvm.org/use/map.html)

从这里也能看出，AS的debug能力是利用LLDB实现的。这里在调试完之后，可以看下data/data/包名 目录下的文件，我们发现，利用as调试后，包的内部存储下会多一个lldb目录，里面包含lldb-server和一个shell脚本。关于shell脚本内容，大家可以自己实操看下，我们后面利用vscode+lldb的调试，也是这样做的。

![](https://raw.githubusercontent.com/MRYangY/blog-img/main/20230107203532.png)





### VSCode+LLDB

##### 准备工作

这种方式，本质上是跟AS一样的，首先我们需要VSCode IDE，接着需要安装lldb的插件，插件：[CodeLLDB插件](https://github.com/vadimcn/vscode-lldb/releases) ，这里可以先安装最新版本，如果不能用再安装**1.7.2**版本。

因为我分别在windows环境和mac环境尝试过，在Mac环境用最新的插件版本没问题，Windows环境最新版本有问题，用1.7.2版本功能正常，应该是lldb的版本不一致导致的，会debug失败。

接着我们需要一个**lldb-server**,用来配置服务端环境，lldb-server从ndk里拿。这里可以看一下上一节末尾提到的lldb目录。

接着分别配置服务端和客户端环境。

##### 服务端

需要把lldb-server 上传到apk，data/data目录下。

1. adb push ***/lldb-server /sdcard/
2. adb shell mv /sdcard/lldb-server /data/local/tmp/
3. adb shell chmod 777 /data/local/tmp/lldb-server
4. adb shell run-as ***packageName*** mkdir test
5. adb shell run-as ***packageName*** cp /data/local/tmp/lldb-server test/lldb-server
6. adb shell run-as ***packageName*** ./test/lldb-server platform --server --listen unix-abstract:///data/local/tmp/debug.sock  ///启动server



上面的操作步骤可以封装到脚本里面去做。





##### 客户端

vscode 配置：

![](https://raw.githubusercontent.com/MRYangY/blog-img/main/20230108102956.png)

打开.vscode/launch.json，修改pid信息，pid获取方式： adb shell pidof "包名"

点击运行和调试，运行Android So Debug任务。

效果：

![](https://raw.githubusercontent.com/MRYangY/blog-img/main/20230108102325.png)



### 参考链接

https://lldb.llvm.org/use/remote.html

https://blog.xhyeax.com/2022/05/06/debug-android-by-gdb-and-lldb/

https://stackoverflow.com/questions/53733781/how-do-i-use-lldb-to-debug-c-code-on-android-on-command-line

https://github.com/vadimcn/vscode-lldb/blob/v1.7.4/MANUAL.md

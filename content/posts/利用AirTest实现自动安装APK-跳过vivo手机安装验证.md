---
title: "利用AirTest实现自动安装APK-跳过vivo手机安装验证"
date: 2023-01-12T21:34:23+08:00
draft: false
tags: ["AirTest", "自动化测试", "自动安装apk"]
categories: ["自动化"]
---

### 利用AirTest实现自动安装APK-跳过vivo手机安装验证



![](https://raw.githubusercontent.com/MRYangY/blog-img/main/hd-wallpaper-2836301_1280.jpg)



### 前言

最近在帮测试组看个问题，他们在自动化测试的时候，通过**adb install** 命令在vivo手机上安装apk的时候出现”**外部来源应用，未经vivo安全性和兼容性检测，请谨慎安装**“的提示页面，需要手动点击”**继续安装**“才可以成功安装apk。提示界面如下：

![](https://raw.githubusercontent.com/MRYangY/blog-img/main/vivo%E6%9C%AA%E7%9F%A5%E6%9D%A5%E6%BA%90%E9%AA%8C%E8%AF%81.jpg)









我们希望可以在安装apk的时候，自动跳过该验证页面。经过调研，发现利用Airtest可以实现该需求。

### 环境配置

本人的开发环境是Windows 10 , python3.11

1. 安装python3.x

2. 安装AirTest IDE   https://airtest.netease.com/

3. 安装AirTest脚本环境

   1. ```python
      //  安装Airtest框架
      pip install airtest
      ```

      

   2. ```python
      // 安装Poco框架；编写了Poco语句就需要安装
      pip install pocoui
      ```

      

   3. ```python
      // 安装airtest-selenium框架；编写了airtest-selenium语句就需要安装
      pip install airtest-selenium
      ```

      



**如果在通过pip install 的时候出现错误，可以尝试加 ”--user“ 后缀。**



Note: 通过AirTest IDE的录制生成脚本功能，可以帮我们快速生成脚本框架，然后在此基础上根据自己的需求结合 airtest脚本文档，来实现具体功能。

### 实现

airtest 的脚本是air文件，其实本质上是python文件。

```python
# -*- encoding=utf8 -*-
__author__ = "bigsponge"

from airtest.core.api import *
import threading


def fun1(threadName, apkPath):
    print(f'start install apk by airtest , thread name: {threadName}, apkPath:{apkPath}')
    install(apkPath)

auto_setup(__file__)

init_device("Android")

t = threading.Thread(target=fun1, args=("thread-install-apk", xxx\xxx\test.apk,))
t.start()

# 根据个人情况调整
sleep(12)

touch(Template(r"tpl1673425386842.png", record_pos=(-0.004, 0.956), resolution=(1080, 2400)))


t.join()

print("install apk by Airtest finished!!")


```

这里重点看下touch方法，通过touch方法可以安装页面上找到“继续安装” 按钮，然后模拟点击“继续安装”，从而实现自动安装。touch方法中，Template的第一个参数是一张图片，这张图片会作为匹配的目标区域。

![](https://raw.githubusercontent.com/MRYangY/blog-img/main/uTools_1673513432902.png)

这个时候，在命令行执行如下命令即可

` python.exe -m airtest run "xxx\Desktop\installApk.air" --device Android:///ip:port`

上面的脚本中，apk地址是内部写死的，如果想要把apk的地址通过命令参数传进来该怎么做呢？

airtest 支持的命令很少，通过

`python.exe -m airtest run -h`

`python.exe -m airtest -h`

发现没有传递自定义参数的选项。

### AirTest自定义参数

通过自定义Airtest启动器可以实现添加自定义参数。

具体实现:

launcher.py

```python
from airtest.cli.runner import AirtestCase, run_script
from airtest.cli.parser import runner_parser


class CustomAirtestCase(AirtestCase):

    def setUp(self):
        # 在air脚本运行之前获取这个自定义的参数
        if self.args.apkpath:
            self.scope['apkpath']=self.args.apkpath

    # def tearDown(self):
    #     pass
    #     super(CustomAirtestCase, self).tearDown()


if __name__ == '__main__':
    ap = runner_parser()
    # 添加自定义的命令行参数
    ap.add_argument(
        "--apkpath", help="install apk path")
    args = ap.parse_args()
    run_script(args, CustomAirtestCase)
```

launcher.py 放在airtest脚本文件内，和 airtest的py文件处于同一级下。

airtest脚本也需要做相应的改动

```python
# -*- encoding=utf8 -*-
__author__ = "bigsponge"

from airtest.core.api import *
import threading


def fun1(threadName, apkPath):
    print(f'start install apk by airtest , thread name: {threadName}, apkPath:{apkPath}')
    install(apkPath)

auto_setup(__file__)

print("apk安装路径是："+apkpath)
print('参数个数为:'+str(len(sys.argv))+'个参数')
print('参数列表:'+str(sys.argv))

init_device("Android")

t = threading.Thread(target=fun1, args=("thread-install-apk", apkpath,))
t.start()


sleep(12)

# touch方法通过指定目标截图来匹配目标
touch(Template(r"tpl1673425386842.png", record_pos=(-0.004, 0.956), resolution=(1080, 2400)))


t.join()

print("install apk by Airtest finished!!")


```

执行如下命令：

`python.exe C:\xxx\Desktop\installApk.air\launcher.py  C:\xxx\Desktop\installApk.air --device Android:///ip:port --apkpath 'C:\xxx\Desktop\APK Installer_8.6.2_Apkpure.apk'`

运行结果：

![](https://raw.githubusercontent.com/MRYangY/blog-img/main/1673514806523.png)



### 封装bat脚本

因为不同的厂商app安装的流程不一样，有的设备不需要经历上面这一通操作，只需要通过adb install就能成功安装，所以我们对不同的手机需要做区分，通过命令行操作不是很方便，封装后的bat脚本：

```vbscript
@echo off

set deviceIp=%1
set devicePort=%2
set airtestScriptPath=%3
set apkPath=%4

echo %deviceIp%
echo %devicePort%
echo %airtestScriptPath%
echo %apkPath%

@rem 添加需要AirTest执行安装的测试手机型号
set specialDeviceList=V2157A
@rem 获取设备型号
for /f "delims=" %%a in ('adb -s %deviceIp%:%devicePort% -d shell getprop ro.product.model') do set deviceType=%%a

echo %deviceType%

for %%i in (%specialDeviceList%) do (
	if %%i==%deviceType% (set findTarget=true) else set findTarget=false
)
echo "test"
if %findTarget%==true (
	python.exe %airtestScriptPath%\launcher.py  %airtestScriptPath% --device Android:///%deviceIp%:%devicePort% --apkpath %apkPath%
) ^
else (
	echo "normal install"
	adb -s %deviceIp%:%devicePort% install %apkPath%
)
```



### 参考

https://airtest.readthedocs.io/en/latest/all_module/airtest.core.api.html#airtest.core.api.connect_device

https://airtest.doc.io.netease.com/IDEdocs/3.4run_script/1_useCommand_runScript/

https://www.cnblogs.com/AirtestProject/p/14606581.html

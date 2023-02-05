---
title: "Android Native开发系列之利用AAudio播放音频"
date: 2023-02-05T20:25:21+08:00
draft: false
tags: ["AAudio", "音频播放"]
categories: ["Android native开发", "音视频"]
---



## Android-Native开发系列之利用AAudio播放音频



![](https://raw.githubusercontent.com/MRYangY/blog-img/main/adult-gd5ec3cd3e_1920.jpg)





### 前言

谈到在Android C/C++层实现音频播放/录制功能的时候，大家可能首先会想到的是利用opensles去做，这确实是一直不错的实现方式，久经考验，并且适配比较广。

但如果你的项目最低版本支持Android 26及以上的话，且想追求最小的延迟，最高的性能。那可以考虑一下AAudio。

博主之前在项目中使用opensles处理音频，后来又分别尝试过利用oboe，aaudio实现音频处理，小有体会，便记录一下，方便自己与他人。

### 什么是AAudio？

AAudio是在Android 8.0时提出的一种新型的C风格接口的Android底层音频库，它的设计目标是追求更高的性能与低延迟。aaudio的设计很单纯，就是播放和录制音频原始数据，拿播放来说的话，就只能播放pcm数据。它不像opensles，opensles可以播放mp3,wav等编码封装后的音频资源。也就是说它不包含编解码模块。

这里简单提一嘴oboe，oboe是对opensles和aaudio的封装。它内部有自己的一个对设备判断逻辑，来选择内部是用aaudio引擎播放声音还是用opensles引擎播放声音。比如在低于Android 8.0的设备，它会选择用opensles播放。

### 配置AAudio开发环境

1. 添加aaudio头文件

   ```c++
   #include <aaudio/AAudio.h>
   ```

2. CMakeLists.txt 链接**aaudio**库

   ```cmake
   target_link_libraries( # Specifies the target library.
           aaudiodemo
           # Links the target library to the log library
           # included in the NDK.
           ${log-lib}
           android
           aaudio)
   ```

   

### AAudioStream

AudioStream 在AAudio中是一个很重要的概念，它的结构体是：AAudioStream。与AAudio交换音频数据实现录音和播放效果的实质上是与AAudio中的AAudioStream交换数据。

我们在使用AAudio播放音频的时候，首先要做的就是创建AAudioStream。

#### 1.创建AAudioStreamBuilder

AAudioStream的创建设计成了builder模式，所以我们需要先创建一个相应的builder对象。

```c++
AAudioStreamBuilder *builder = nullptr;
aaudio_result_t result = AAudio_createStreamBuilder(&builder);
if (result != AAUDIO_OK) {
	LOGE("AAudioEngine::createStreamBuilder Fail: %s", AAudio_convertResultToText(result));
}
```

#### 2.配置AAudioStream

通过builder的setXXX函数来配置AAudioStream。

```c++
AAudioStreamBuilder_setDeviceId(builder, AAUDIO_UNSPECIFIED);
AAudioStreamBuilder_setFormat(builder, mFormat);
AAudioStreamBuilder_setChannelCount(builder, mChannel);
AAudioStreamBuilder_setSampleRate(builder, mSampleRate);

// We request EXCLUSIVE mode since this will give us the lowest possible latency.
// If EXCLUSIVE mode isn't available the builder will fall back to SHARED mode.
AAudioStreamBuilder_setSharingMode(builder, AAUDIO_SHARING_MODE_EXCLUSIVE);
AAudioStreamBuilder_setPerformanceMode(builder, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
AAudioStreamBuilder_setDirection(builder, AAUDIO_DIRECTION_OUTPUT);
// AAudioStreamBuilder_setDataCallback(builder, aaudiodemo::dataCallback, this);
// AAudioStreamBuilder_setErrorCallback(builder, aaudiodemo::errorCallback, this);
```

简述一下上面的函数，具体大家可以看源码里面的注释。

- DeviceId----指定物理音频设备，例如内建扬声器，麦克风，有线耳机等等。这里AAUDIO_UNSPECIFIED表示有AAudio根据上下文自行决定，如果是播放音频的话，一般它会选择扬声器。
- format，channel，sample就不细说了，很容易理解，这里提一嘴的是，测试下来发现AAudio只支持单声道和双声道音频，5.1、7.1这种多声道音频，不支持播放。opensles也是，虽然提供了多声道的枚举值，但是当真正设置进去的时候，会提示说不支持。
- SharingMode 分为：**AAUDIO_SHARING_MODE_EXCLUSIVE** 和 **AAUDIO_SHARING_MODE_SHARED** ，因为AAudioStream是要和device绑定的，独占模式就是独占这个audio device，别的audio stream不能访问，独占模式下延迟会更小，但是要注意不用的时候及时关闭释放，不然别的流没法访问该audio device了。共享模式就是多个音频流可以共享一个audio device，官方说共享模式下，同一个audio device所有音频流可以实现混音，这个混音我还没试，后面抽空试试。到时候会在文末补充结论。
- PerformanceMode： 
  - **AAUDIO_PERFORMANCE_MODE_NONE**  默认模式，在延迟和省电间，自己平衡
  - **AAUDIO_PERFORMANCE_MODE_LOW_LATENCY** 更注重延迟
  - **AAUDIO_PERFORMANCE_MODE_POWER_SAVING** 更注重省电
- Direction 
  - **AAUDIO_DIRECTION_INPUT**  录音的时候用
  - **AAUDIO_DIRECTION_OUTPUT**  播放的时候用

最后两行被注释的回调，我们后面再说。

#### 3.创建AAudioStream

```c
aaudio_result_t  AAudioStreamBuilder_openStream(AAudioStreamBuilder* builder,
        AAudioStream** stream)
```

通过openStream函数，获取到指定配置的AAudioStream对象，接着就可以拿着audio stream处理音频数据了。这里在成功创建玩AAudioStream之后，可以通过调用AAudioStream的相关getXXX函数，获取“***真正***” audio stream配置，之前通过audio stream builder设置的配置是我们的意向配置，一般来说，意向配置就是最终配置，但是也会存在偏差，所以在调式阶段，最好再打印一下，真正的audio stream配置，帮助开发者获取确切信息。

| [`AAudioStreamBuilder_setDeviceId()`](https://developer.android.com/ndk/reference/group___audio#gaab12dd029554b2928cac6bb057903525) | [`AAudioStream_getDeviceId()`](https://developer.android.com/ndk/reference/group___audio#ga1914721c39f9400c6a7e32b11908b066) |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| [`AAudioStreamBuilder_setDirection()`](https://developer.android.com/ndk/reference/group___audio#ga22a61c42068a5733d0d4c7b4114c3333) | [`AAudioStream_getDirection()`](https://developer.android.com/ndk/reference/group___audio#ga8845709a1ea64e18eed9255c15a8402b) |
| [`AAudioStreamBuilder_setSharingMode()`](https://developer.android.com/ndk/reference/group___audio#gaa5edd7941e1dc11cc7dbf5b35dd54841) | [`AAudioStream_getSharingMode()`](https://developer.android.com/ndk/reference/group___audio#ga51b7db27bdd331c22d8443a50033a17a) |
| [`AAudioStreamBuilder_setSampleRate()`](https://developer.android.com/ndk/reference/group___audio#ga8b7930b6b7251e6a73c601030c7ce2b2) | [`AAudioStream_getSampleRate()`](https://developer.android.com/ndk/reference/group___audio#ga2f3f5739425578c6c8e61c02f53528ce) |
| [`AAudioStreamBuilder_setChannelCount()`](https://developer.android.com/ndk/reference/group___audio#ga8d7461d982bbff630dea6546ec7e9844) | [`AAudioStream_getChannelCount()`](https://developer.android.com/ndk/reference/group___audio#gac04633015b26345d2f2fa97d32e0d643) |
| [`AAudioStreamBuilder_setFormat()`](https://developer.android.com/ndk/reference/group___audio#gacdf4cd79e60923c300bc81e7ab032713) | [`AAudioStream_getFormat()`](https://developer.android.com/ndk/reference/group___audio#ga90831503bace94aa6a650baba29aec36) |
| [`AAudioStreamBuilder_setBufferCapacityInFrames()`](https://developer.android.com/ndk/reference/group___audio#ga4dbce24e8b60b733ddbe2a76052e66f0) | [`AAudioStream_getBufferCapacityInFrames()`](https://developer.android.com/ndk/reference/group___audio#ga887c8e56710452305f229907be60a046) |

在创建完成AAudioStream后，需要释放AAudioStreamBuilder对象。

```c
AAudioStreamBuilder_delete(builder);
```

#### 4.操作AAudioStream

- AAudioStream 的生命周期
  - Open
  - Started
  - Paused
  - Flushed
  - Stopped
  - Disconnected
  - Error

我们先说前五种状态，它们的状态变化可以用下面的流程图表示，虚线框表示瞬时状态，实线框表示稳定状态：

![](https://raw.githubusercontent.com/MRYangY/blog-img/main/aaudio-lifecycle.png)

其中涉及的函数有：

```c++
aaudio_result_t result;
result = AAudioStream_requestStart(stream);
result = AAudioStream_requestStop(stream);
result = AAudioStream_requestPause(stream);
result = AAudioStream_requestFlush(stream);
```

上面的这些函数是异步调用，不会阻塞。也就是，调用完函数后，audio stream的状态不会立马转移到指定状态。它会先转移到相应的瞬时状态，看上面的流程图就能知道，相应的瞬时状态有如下几种：

- Starting
- Pausing
- Flushing
- Stopping
- Closing

那调用完requestXXX函数后，怎么知道状态真正切换到相应的状态呢？一般来说，我们没必要知道这个信息，所以AAudio对于这方面支持一般，都没提供什么接口。如果你有这方面的需求的话，那么可以看看，下面的函数，可以勉强符合你的需求。

```c
aaudio_result_t AAudioStream_waitForStateChange(AAudioStream* stream,
        aaudio_stream_state_t inputState, aaudio_stream_state_t *nextState,
        int64_t timeoutNanoseconds)
```

这个函数需要注意的是**inputState** 和 **nextState**参数，inputState参数代表当前的状态，可以通过**AAudioStream_getState**获取，**nextState是指状态发生变化后，新的状态值，这里新的状态值是不确定的，但有一点确定的是，一定跟inputState值不一样**。

```c
aaudio_stream_state_t inputState = AAUDIO_STREAM_STATE_PAUSING;
aaudio_stream_state_t nextState = AAUDIO_STREAM_STATE_UNINITIALIZED;
int64_t timeoutNanos = 100 * AAUDIO_NANOS_PER_MILLISECOND;
result = AAudioStream_requestPause(stream);
result = AAudioStream_waitForStateChange(stream, inputState, &nextState, timeoutNanos);
```

例如上面的代码，waitForStateChange函数调用后，nextState就一定是Paused吗？不一定，有可能是其他的状态，比如：Disconnected，但是nextState一定不等于inputState。

**注意**

- 不要在调用AAudioStream_close之后，调用waitForStateChange函数
- 当其他线程运行waitForStateChange函数时，不要调用AAudioStream_close函数

#### 5.AAudioStream处理音频数据

当audio stream启动后，有两种方式来处理音频数据。

- 通过***AAudioStream_write***和***AAudioStream_read***函数向流里写数据和读数据，使用此方式需要自己创建线程控制数据读写。
- 通过callback的方式，使用此方式，会更高效，延迟更低，是官方推荐的方式

##### 通过write、read函数直接读写数据

先看下函数原型：

```c
aaudio_result_t AAudioStream_write(AAudioStream* stream,
                               const void *buffer,
                               int32_t numFrames,
                               int64_t timeoutNanoseconds)
```

buffer: 音频原始数据

numFrames：请求处理的帧数，例如：16位双声道的数据，那么该值就是：bufferSize/(16/8)/2

timeoutNanoseconds: 最长阻塞时间，当值为0时，表示不阻塞

return value: 表示实际处理的帧数

知道函数的使用方式后，我们就可以在愉快的往里面填充数据了~

##### 通过callback回调的方式处理数据

为什么官方说推荐使用callback方式呢，主要原因我认为有几点：

1. 使用callback方式，aaudio内部会通过一个高优先级的优化后的专属线程处理回调，会避免因线程抢占等问题出现杂音。
2. 使用callback方式，延迟更低。
3. 使用直接向流里读写数据，需要自己维护一个播放线程，成本高，且有bug风险。而且如果要创建多个音频播放器，考虑出现多个线程，进而出现资源紧张的问题。

那这么说，是不是就一定得用callback方式了呢，也不是，经过作者的测试发现，关于延迟的指标，除非对延迟要求很高的产品，大多数情况下，使用直接读写数据到流的方式也是没问题的。所以选择具体方案还是要根据项目的真实情况决定。

具体怎么通过callback的方式处理数据呢？

还记得在**配置AAudioStream**这一节的时候，被注释的两行代码嘛。

`// AAudioStreamBuilder_setDataCallback(builder, aaudiodemo::dataCallback, this);`
`// AAudioStreamBuilder_setErrorCallback(builder, aaudiodemo::errorCallback, this);`

当使用callback模式处理音频数据的时候，就需要设置这两个函数。

---

**dataCallback** 在AAudio需要数据时触发，我们只需要往里面写入指定大小的数据即可。

```c
typedef aaudio_data_callback_result_t (*AAudioStream_dataCallback)(
        AAudioStream *stream,
  			///上下文环境
        void *userData,
  			///填充音频数据
        void *audioData,
  			///需要填充多少帧数据，具体的换算方式：dataSize = numFrames*channels*(format == AAUDIO_FORMAT_PCM_I16 ? 2 : 1)
        int32_t numFrames);
```

该回调的返回值有两种：

- AAUDIO_CALLBACK_RESULT_CONTINUE  表示继续播放
- AAUDIO_CALLBACK_RESULT_STOP  表示停止播放，该回调不会再触发

**注意：**

因为dataCallback会频繁调用。所以最好不要在此回调中做一下耗时的，很重的任务。



**errorCallback** 当出现错误发生的时候或者断开连接的时候，此回调会被触发。常见的一个例子是：如果audio device disconnected时，会触发errorCallback，这个时候需要新开一个线程，重新创建AAudioStream。

```c
typedef void (*AAudioStream_errorCallback)(
        AAudioStream *stream,
        void *userData,
        aaudio_result_t error);
```

**注意：**

在此回调中，下列函数不要直接调用，需要新开一个线程处理

```c
AAudioStream_requestStop()
AAudioStream_requestPause()
AAudioStream_close()
AAudioStream_waitForStateChange()
AAudioStream_read()
AAudioStream_write()
```

AAudioStream相关的getXXX函数可以直接调用，如：AAudioStream_get*()**

关于AAudio的使用demo，已上传至github，觉得不错的话，就给个star吧~ღ( ´･ᴗ･` )比心

[AAUDIODEMO]: https://github.com/MRYangY/AAudioDemo

#### 6.销毁AAudioStream

```c
AAudioStream_close(stream);
```



### Extra Info

上面的章节属于必须内容，下面的为补充内容，按需了解。

#### underrun & overrun

underrun和overrun是音频数据的生产与消费节奏不匹配导致的。

underrun 是指在播放音频的时候，没有及时往audio stream写入的数据，系统没有可用的音频数据。

overrun 是指在录制音频的时候，没有及时的从audio stream读取数据，导致音频没人接收，就给丢了。

这两种情况都会导致音频出现问题。

AAudio是怎么解决这种问题呢？

利用动态调整缓冲区大小来降低延迟，避免underrun。涉及到的函数有：

```cpp
///app一次处理音频的数据量-(帧数)，返回的值是经过系统优化后的适应低延迟的值，可作为出现XRun时的StepSize
int32_t AAudioStream_getFramesPerBurst(AAudioStream* stream);
///缓冲区大小设置，实现低延迟的，解决xrun的本质就是动态的调节这个size的大小
aaudio_result_t AAudioStream_setBufferSizeInFrames(AAudioStream* stream,int32_t numFrames);
int32_t AAudioStream_getBufferSizeInFrames(AAudioStream* stream)
///通过该方法，可以知道是否发生underrun或者overrun，进而决定该如何调整缓冲区大小
int32_t AAudioStream_getXRunCount(AAudioStream* stream)
```

演示调用流程：

```c++
int32_t previousUnderrunCount = 0;
int32_t framesPerBurst = AAudioStream_getFramesPerBurst(stream);
///通常在最开始的时候把framesPerBurst的值通过AAudioStream_setBufferSize设置给bufferSize，让它两一样会更容易达到低延迟
int32_t bufferSize = AAudioStream_getBufferSizeInFrames(stream);
int32_t bufferCapacity = AAudioStream_getBufferCapacityInFrames(stream);

while (run) {
  	/// 向AAudioStream写数据
    result = writeSomeData();
    if (result < 0) break;

    // Are we getting underruns?
    if (bufferSize < bufferCapacity) {
        int32_t underrunCount = AAudioStream_getXRunCount(stream);
        if (underrunCount > previousUnderrunCount) {
            previousUnderrunCount = underrunCount;
            // Try increasing the buffer size by one burst
            bufferSize += framesPerBurst;
            bufferSize = AAudioStream_setBufferSize(stream, bufferSize);
        }
    }
}
```

上面的代码很容易理解，就是刚开始会初始化一块小的buffer, 当发生underrun的时候，根据framesPerBurst不断的增大buffer，来实现低延迟。

#### Thread safety

AAudio的接口不是完全线程安全的。在使用的时候需要注意：

- 不要在多个线程并发调用AAudioStream_waitForStateChange()/read/write函数。
- 不要在一个线程关闭流，另一个线程读写流。

线程安全的有：

- `AAudio_convert*ToText()`
- `AAudio_createStreamBuilder()`
- `AAudioStream_get*()` 系列函数，除了 `AAudioStream_getTimestamp()`



### 结论

aaudio接口很简单，跟opensles的代码量相比，少多了。不过功能比opensles少一些。像是解码，控制音量等，aaudio都木有。大家看自己需求选择吧。

给个demo工程链接，配合着文章看看就懂了。

https://github.com/MRYangY/AAudioDemo


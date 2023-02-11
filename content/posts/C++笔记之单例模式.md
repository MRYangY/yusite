---
title: "C++笔记之单例模式"
date: 2023-02-11T17:31:07+08:00
draft: false
tags: ["单例模式", "C++"]
categories: ["C++学习笔记"]
---



## C++笔记之单例模式

![](https://raw.githubusercontent.com/MRYangY/blog-img/main/C%2B%2B%E7%AC%94%E8%AE%B0%E4%B9%8B%E5%8D%95%E4%BE%8B-%E5%B0%81%E9%9D%A2.jpg)

### 前言

当一个类在程序的整个生命周期中，只需要一个实例的时候，就可以考虑把这个类设计成单例的方式，提供出去，让全局访问。一般来说比较 **“重”** 的一些类会设计成单例，比如像“引擎”， “xx池”，“xx系统”之类的。



### 实现方式一(推荐)

Singleton.h

```c++
#pragma once
class Singleton {
 private:
  Singleton(/* args */);
  Singleton(const Singleton &) = default;
  Singleton &operator=(const Singleton &) = default;

 public:
  ~Singleton();
  static Singleton &GetInstance();

  void doSomething();
};
```

Singleton.cpp

```c++
#include "Singleton.h"

#include <iostream>
using namespace std;
Singleton::Singleton() { cout << "Singleton constructor!!" << endl; }

Singleton::~Singleton() { cout << "Singleton destructor!!" << endl; }

Singleton& Singleton::GetInstance() {
  static Singleton sInstance;
  return sInstance;
}

void Singleton::doSomething() { cout << "Singleton::doSomething!!" << endl; }

```

Main.cpp

```c++
#include <iostream>

#include "Singleton.h"
using namespace std;
int main(int argc, char **argv) {
  cout << "hello world!" << endl;
  Singleton::GetInstance().doSomething();
  return 0;
}
```

执行结果：

hello world!
Singleton constructor!!
Singleton::doSomething!!
Singleton destructor!!



**利用局部静态变量特性，线程安全，懒加载**



---

### 实现方式二

利用智能指针和锁实现的double check单例模式

Singleton.h

```c++
#pragma once
#include <mutex>
class Singleton {
 private:
  Singleton(/* args */);
  Singleton(const Singleton &) = default;
  Singleton &operator=(const Singleton &) = default;

 private:
  static std::mutex sMutex;
  static std::shared_ptr<Singleton> sInstance;

 public:
  ~Singleton();
  static std::shared_ptr<Singleton> GetInstance();

  void doSomething();
};
```

Singleton.cpp

```c++
#include "Singleton.h"

#include <iostream>
using namespace std;

std::mutex Singleton::sMutex;
std::shared_ptr<Singleton> Singleton::sInstance = nullptr;

Singleton::Singleton() { cout << "Singleton constructor!!" << endl; }

Singleton::~Singleton() { cout << "Singleton destructor!!" << endl; }

std::shared_ptr<Singleton> Singleton::GetInstance() {
  if (sInstance == nullptr) {
    std::lock_guard<std::mutex> lock(sMutex);
    if (sInstance == nullptr) {
      sInstance = std::make_shared<Singleton>();///注释一
    }
  }
  return sInstance;
}

void Singleton::doSomething() { cout << "Singleton::doSomething!!" << endl; }

```

这里注意一下，注释一部分的代码，不可以使用std::make_shared<>的方式创建智能指针，会出现下面的错误。

![](https://raw.githubusercontent.com/MRYangY/blog-img/main/20230211152004.png)

需要改成：

```c++
sInstance = std::shared_ptr<Singleton>(new Singleton());
```

除此之外，这里在选择智能指针的时候，最好选择shared_ptr，而不是unique_ptr，因为unique_ptr **无法进行复制构造和赋值操作**，它的拷贝构造函数和赋值构造函数被删除了。

执行结果：

hello world!
Singleton constructor!!
Singleton::doSomething!!
Singleton destructor!!

---



### link

https://www.cnblogs.com/sunchaothu/p/10389842.html


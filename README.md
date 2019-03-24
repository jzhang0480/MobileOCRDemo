#### 集成
##### 1.使用cocoapods集成
```
target 'MobileOCRDemo' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for MobileOCRDemo
  pod 'TesseractOCRiOS', '~> 5.0.1'

end
```
这个库比较大，估计pod install速度会比较慢，加速参考：[gem install、brew install、pod install速度慢的终极解决办法](https://www.jianshu.com/p/600563b41284)
#####2.导入训练好的识别数据文件。
![image.png](https://upload-images.jianshu.io/upload_images/1653855-ba10fbf3bef1fffe.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
注意事项：
**1.文件夹名称和文件名称不能改。并且必须用我demo里的文件，这个文件有版本要求，找最新的是用不了的。**
**2.导入文件方式要直接拖入tessdata文件夹，选Create folder references**
![image.png](https://upload-images.jianshu.io/upload_images/1653855-f03e54794dcefe3b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#####3.其它的看demo里面的代码吧
具体TesseractOCRiOS的使用下次另开文章写，只是需要识别手机号的话，这篇文章和demo已经足够了。
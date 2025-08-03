# MisonoTalk

### 这是什么
源于@k96e  的项目 [Github Release](https://github.com/k96e/MisonoTalk/releases)，进行一些适应我使用的功能变更，因此单独作为MisonoTalk探索版开发，  

项目整体皆为@k96e创建。以下是其本人对MisonoTalk的视频介绍:
 [Bilibili](https://www.bilibili.com/video/BV1YBvXenEZK)
源项目地址:


### 使用
#### 配置
 点击右上角×， 选择Settings，配置模型api
 ```
 名称       该配置项的名称，自定
 base url   api的base_url，模型文档会提供
 api key    api密钥
 model      使用的模型名
 ```
 保存后确定即可

#### 关于备份
 在设置页点击备份会默认导出备份文件到设备的下载目录，备份中文件除了保存的对话外还有明文api密钥等敏感信息，请勿轻易分享到公开平台

#### 关于AI绘画
 使用[这个HuggingFace Space](https://r3gm-diffusecraft.hf.space/)作为api，你需要Duplicate this Space，获取自己的hf space url

#### 关于加密
 [Commit a05bb73](https://github.com/k96e/MisonoTalk/commit/a05bb737e8598ecdde6c2c3fd7cdbf6d3ebf55e8) 之后，通过WebDav进行备份或同步时支持端到端加密，如需使用请在所有设备的WebDav配置中设置相同的Encrypt Key. 提供外部解密脚本，位于`scripts/decrypt.py`

### 叠甲
- 自用项目能跑就行，代码很烂
- 未花的设定基于个人偏好肯定有失偏颇，想要修改提示词可以直接覆盖`assets/prompt.txt`
- 没有对提示词攻击做任何防范，钓鱼铁上钩
- 本地部署版暂时没做联网搜索和事实核查能力，涉及游戏设定和具体剧情的内容是肯定会瞎编的
- 不可以色色
- `assets/prompt.txt`中的预设提示词保留权利，请勿移作他用

项目中引用的所有图片版权归属Nexon

# searchlogs - 日志查找工具

> [github searchlogs](https://github.com/gitHusband/searchlogs)

一般看日志，我们使用 `find + grep` 命令已经足够。

**为什么写 searchlogs?**
常规的方法，有一些不足：
1. 日志文件多，且可能分布在不同目录下，不能一次性查找
2. 日志中包含不需要的内容，难以过滤
3. 日志不能按时间点搜索
4. 不能持久化

`searchlogs` 就是为了解决这些痛点而写的。

**特点：**
- 支持多个日志文件同时搜索指定内容
- 支持设置日志文件/日志行的最小匹配时间
- 支持配置文件，时间，指定内容等的匹配规则
- 支持持久化搜索结果
- 支持后台监听文件增长，包括新增文件

**安装**
[github 下载文件 searchlogs.sh](https://github.com/gitHusband/searchlogs/blob/main/searchlogs.sh)

**例子：**
```bash
$ ./searchlogs.sh --path /data/path
```
[TOC]

## 选项

### -p, --path 搜索目录
设置查找日志文件的目录

**默认**：脚本所在目录

例如，在目录 /data/path 中搜索日志
```bash
$ ./searchlogs.sh --path /data/path
```

### -n, --name 文件名
日志文件名的正则表达式

**默认**： `*.log`

例如，在当前目录中搜索所有以 .txt 的文件
```bash
$ ./searchlogs.sh --name *.txt
```

### -s, --start-datetime 起始时间
搜索在此时间之后写入的日志

**默认**：昨天零点

例如，搜索所有 "2023-03-31 12:00:00" 之后产生的日志
```bash
$ ./searchlogs.sh --start-datetime "2023-03-31 12:00:00"
```

### -m, --match-reg 行匹配规则
搜索与此正则表达式匹配的日志文件行

**默认**： `^ERROR|WARNING|CRITICAL`，即所有以 **ERROR** 或者 **WARNING** 或者 **CRITICAL** 开头的行

例如，搜索所有包含 **error** 字符串的行
```bash
$ ./searchlogs.sh --match-reg error
```

### --find-opts find选项
理论上，支持 find 命令的所有选项

**默认**：无

例如，搜索所有文件名以 **.log 结尾** 或者 **以 log 开头 .php 结尾** 的文件, 且修改时间在一小时以内
```bash
$ ./searchlogs.sh --find-opts "-o -name log*.php -mmin -60"
```

### --save-log
保存搜索日志的结果
保存结果的好处是：
- 重复查看搜索结果
- 结果文件最后一行添加搜索详情，包括文件总行数，匹配行数以及搜索时间
- 保存路径不变的话，再次执行命令，可以忽略以前搜索过的内容

**默认**：不保存

例如，保存搜索结果
```bash
$ ./searchlogs.sh --save-log
```
- 默认将结果保存到目录 `./searchlogs_result`
- 结果文件以 `.search` 结尾
- 文件内若无匹配行，则隐藏结果文件

### --save-path 保存路径
设置保存搜索结果的目录

**默认**： `./searchlogs_result`

例如，将搜索结果保存到目录 `/data/search/searchlogs_result`
```bash
$ ./searchlogs.sh --save-log --save-path /data/search
```

### -c, --clean
清理搜索结果并退出

例如，
```bash
$ ./searchlogs.sh -c
```

### --reset
清理搜索结果，并重新搜索

例如，在目录 /data/path 中搜索日志前，先清理上一次的搜索结果
```bash
$ ./searchlogs.sh --path /data/path --save-log --reset
```

### --line-offset-reg 偏移匹配规则
当匹配 --match-reg 的行，同时满足 --line-offset-reg 匹配，允许匹配行往后的 lineOffset 这几行，都无需匹配直接打印

**格式**: `reg1,lineOffset1,reg2,lineOffset2` 以逗号分隔
- 如果行与 reg1 匹配，则往后 lineOffset1 行，直接打印

**默认**：
- `"^CRITICAL": 5` - 以字符串 **CRITICAL** 开头的行，之后的 5 行直接打印无需匹配

例如，匹配行中包含字符串 `Undefined array key`, 则在其之后的 3 行直接打印
```bash
$ ./searchlogs.sh --line-offset-reg "Undefined array key,3"
```

又如，不偏移打印，即所有行均需匹配 --match-reg 才能打印
```bash
$ ./searchlogs.sh --line-offset-reg ""
```

### --file-time-reg 文件时间匹配规则
匹配文件名的日期，并将其转换为时间戳，用于与 --start-datetime 比较
若日期小于 --start-datetime，则忽略此文件

**格式**: `reg1,format1,reg2,format2` 以逗号分隔
- 如果行与 reg1 匹配，则以 format1 的格式转换为时间戳，并以此与 --start-datetime 比较大小

**默认**：
- `"^.*/.*([0-9]{4}-[0-9]{2}-[0-9]{2})": "%Y-%m-%d"`, 例如 2023-04-01
- `"^.*/.*([0-9]{8})": "%Y%m%d"`, 例如 20230401

例如，匹配文件中的日期格式 YYYY_mm_dd
```bash
$ ./searchlogs.sh --file-time-reg "([0-9]{4}_[0-9]{2}_[0-9]{2}),%Y_%m_%d"
```

又如，不通过时间排除任何文件
```bash
$ ./searchlogs.sh --file-time-reg ""
```

如果你的日期格式够特殊，导致默认的日期补全函数无法转换日期为时间戳，怎么办呢？
假如你的格式是 "%d%m%Y"，正常的日期例如（01042023），但你的是 （142023）
这就需要你自己定义日期补全函数，请参考以下《定义文件日期补全函数》

### --line-time-reg 行时间匹配规则
匹配行的日期，并将其转换为时间戳，用于与 --start-datetime 比较
若日期小于 --start-datetime，则忽略此行

**格式**: `reg1,format1,reg2,format2` 以逗号分隔
- 如果行与 reg1 匹配，则以 format1 的格式转换为时间戳，并以此与 --start-datetime 比较大小

**默认**：
- `"([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})": "%Y-%m-%d %H:%M:%S"`，例如， 2023-04-01 12:00:00

例如，匹配文件中的日期格式 *YYYY_mm_dd* *H*:*m*:*s*
```bash
$ ./searchlogs.sh --line-time-reg "([0-9]{4}_[0-9]{2}_[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}),%Y_%m_%d %H:%M:%S"
```

又如，不通过时间排除任何行
```bash
$ ./searchlogs.sh --line-time-reg ""
```

如果你的日期格式够特殊，导致默认的日期补全函数无法转换日期为时间戳，怎么办呢？
假如你的格式是 "%d%m%Y%H%M%S"，正常的日期例如（01042023120101），但你的是 （14202312159）
这就需要你自己定义日期补全函数，请参考以下《定义行日期补全函数》

### -f, --follow 监听模式
后台监听文件增长，包括新增文件

例如，监听目录 /data/path 中所有以 .log 结尾的文件，包括在此之后创建的文件 
```bash
$ ./searchlogs.sh --path /data/path --save-log -f
```
- 监听模式下，不会立即在结果文件最后一行添加搜索详情
- 脚本退出前，在结果文件最后一行添加搜索详情

### -h, --help 帮助文档
打印帮助文档

## 配置文件
由于可变因素太多，如果不想繁琐地设置选项，可一次性设置所有适合您自己的配置

在相同目录下，创建 `config.sh` 文件

### 基础配置
```bash
#!/usr/bin/env bash
# Replace !/bin/bash, because Mac `brew install bash`, the bash is /usr/local/bin/bash, not /bin/bash

# Set By Option: -p, --path
# Find log files in here
path=`pwd`
# Set By Option: -n, --name
# Regular expression of log file name
name='*.log'
# Set By Option: -s, --start-datetime
# Search the logs write after this time
startDatetime=$(getDefaultDatetime)
startTimestamp=$(defaultDateToTime "$startDatetime")
# Set By Option: -m, --match-reg
# Search the lines of log files that match this regular expression
matchReg="^ERROR|WARNING|CRITICAL"
```
- 完整配置文件请参考： [config.example.sh](https://github.com/gitHusband/searchlogs/blob/main/config.example.sh)

~~编写配置文件要求您有一定的 shell 基础~~
需要注意的是，可以设置多个内容的选项。

以 `--file-time-reg` 为例，这里以 逗号 分隔多个内容
```bash
--file-time-reg "([0-9]{4}_[0-9]{2}_[0-9]{2}),%Y_%m_%d"
```
对应的配置数组为，以 小括号 包裹，以 空格 分隔
```bash
fileDatetimeRegs=(
    "([0-9]{4}_[0-9]{2}_[0-9]{2})" "%Y_%m_%d"
)
```

### 定义文件日期补全函数
如果你的文件日期格式够特殊，导致默认的日期补全函数无法转换日期为时间戳，怎么办呢？
假如你的格式是 "%d%m%Y"，正常的日期例如（01042023），但你的是 （142023）
这就需要你自己定义日期补全函数
```shell
# 定义你的文件日期补全函数
myFileDateComplete()
{
    # 日期及其格式初始值是
    # fileDatetimeFormat="%d%m%Y"
    # fileDatetime="142023"

    # 你要做的就是把它们转换成 2023-04-01 23:59:59
    fileDatetimeFormat="%Y-%m-%d %H:%M:%S"
    fileDatetime="2023-04-01 23:59:59"
}
# 最后将函数赋值给 lineDateCompleteHandlers["%d%m%Y%H%M%S"]
fileDateCompleteHandlers["%d%m%Y"]=myFileDateComplete
```

### 定义行日期补全函数
如果你的行日期格式够特殊，导致默认的日期补全函数无法转换日期为时间戳，怎么办呢？
假如你的格式是 "%d%m%Y%H%M%S"，正常的日期例如（01042023120101），但你的是 （14202312159）
这就需要你自己定义日期补全函数
```shell
# 定义你的行日期补全函数
myLineDateComplete()
{   
    # 日期及其格式初始值是
    # lineDatetimeFormat="%d%m%Y%H%M%S"
    # lineDatetime="14202312159"

    # 你要做的就是把它们转换成 2023-04-01 12:01:59
    lineDatetimeFormat="%Y-%m-%d %H:%M:%S"
    lineDatetime="2023-04-01 12:01:59"
}
# 最后将函数赋值给 lineDateCompleteHandlers["%d%m%Y%H%M%S"]
lineDateCompleteHandlers["%d%m%Y%H%M%S"]=myLineDateComplete
```

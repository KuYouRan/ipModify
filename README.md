能够修改Linux系统（Centos、Ubuntu、Deepin）的ip地址，有两个选择： 

1. 随机生成一个当前网段的ip 
2. 你自己写一个当前网段的ip  

下载脚本
`git clone https://github.com/KuYouRan/ipModify.git`

授权执行权限
`chmod u+x ipModify.sh`

执行脚本
`./ipModify.sh`

PS：
下载该脚本执行后，若ip没变化，请自行根据你的系统执行相应的重启网卡的命令，或者统一执行reboot重启系统，就能让新修改的ip生效。

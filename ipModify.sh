#!/bin/bash
# 提示语
echo "详细信息请查看ipModify目录下的log日志文件。"
echo "Please check the log file under the ipModify directory for more details."
echo "詳細な情報につきましては、「ipModify」ディレクトリ内のログファイルをご確認ください。"
echo "---"

# 获取当前用户主目录路径
HOME_DIR=$(eval echo ~${SUDO_USER:-$USER})

# 创建日志文件夹并获取其路径
LOG_DIR="${HOME_DIR}/ipModify"
mkdir -p $LOG_DIR

# 获取当前时间并构造日志文件名
CURRENT_TIME=$(date +"%Y%m%d%H%M%S")
LOG_FILE="${LOG_DIR}/ipModify${CURRENT_TIME}.log"

# 记录修改前的IP信息到日志文件
echo "Before modification:" >> $LOG_FILE
ip addr show dev ens33 >> $LOG_FILE

# 输出选项列表，让用户选择1、2或3
while true; do
  # 根据系统语言显示提示语
  lang=$(echo ${LANG} | cut -d'.' -f1)
  case $lang in
    "zh_CN")
      echo "请选择以下选项："
      echo "1. 随机生成一个 IP 地址"
      echo "2. 输入自定义 IP 地址"
      echo "3. 退出"
      read -p "请输入您的选择（1、2 或 3）：" choice
      ;;
    "en_US")
      echo "Please choose an option below:"
      echo "1. Randomly generate an IP address"
      echo "2. Enter a custom IP address"
      echo "3. Exit"
      read -p "Enter your choice (1, 2 or 3): " choice
      ;;
    "ja_JP")
      echo "以下のオプションから選択してください："
      echo "1. IP アドレスをランダムに生成する"
      echo "2. カスタム IP アドレスを入力する"
      echo "3. 終了する"
      read -p "選択してください（1、2、または 3）：" choice
      ;;
    *)
      echo "Unsupported language: $lang"
      exit 1
      ;;
  esac

  case $choice in
    1)
      # 随机生成当前网段下的IP地址
      current_ip=$(ip addr show dev ens33 | awk '/inet /{print $2}')
      prefix=$(echo $current_ip | cut -d '.' -f 1-3)
      suffix=$((1 + RANDOM % 254))
      new_ip="${prefix}.${suffix}"
      echo "Generating random IP address: $new_ip"
      break
      ;;
    2)
      # 提示用户输入自定义IP地址
      read -p "Please enter the new IP address: " new_ip
      break
      ;;
    3)
      # 退出脚本
      echo "Exiting ipModify."
      exit
      ;;
    *)
      echo "Invalid choice, please try again."
      ;;
  esac
done

# 将IP设置为静态IP
echo "Configuring static IP..." >> $LOG_FILE
os_name=$(cat /etc/*-release | grep '^ID=' | awk -F= '{print $2}')
if [ "$os_name" == "ubuntu" ]; then
  # Ubuntu系统
  cfg_file="/etc/netplan/50-cloud-init.yaml"
  sed -i 's/dhcp/static/' $cfg_file
  sed -i "/addresses:/c\ \ \ \ addresses: [$new_ip/24]" $cfg_file
  sudo netplan apply >> $LOG_FILE 2>&1
  sudo ip address flush dev ens33 >> $LOG_FILE 2>&1
  sudo systemctl restart systemd-networkd.service >> $LOG_FILE 2>&1
  
  # 等待网络服务重启完成
  sleep 2
elif [ "$os_name" == "deepin" ]; then
  # Deepin系统
  
  # 判断Deepin版本号
  deepin_version=$(cat /etc/deepin-version | awk '{print $2}')
  if [[ "$deepin_version" == "20.*" ]]; then
    # Deepin 20.x版本
      
    # 修改配置文件
    cfg_file="/etc/systemd/network/50-wired.network"
    sed -i '/\[Network\]/a Address='"$new_ip/24"'' $cfg_file
    sed -i '/\[Network\]/a DHCP=no' $cfg_file
    sed -i '/\[Network\]/a DNS=223.5.5.5 223.6.6.6 8.8.8.8' $cfg_file
    sed -i '/\[Match\]/a Name=ens33' $cfg_file
      
    # 重启网络服务
    sudo systemctl restart systemd-networkd.service >> $LOG_FILE 2>&1
  
    # 等待网络服务重启完成
    sleep 5
  elif [[ "$deepin_version" == "15.*" ]]; then
    # Deepin 15.x版本
      
    # 修改配置文件
    cfg_file="/etc/network/interfaces"
    sudo sed -i '/auto ens33/d' $cfg_file
    sudo echo "auto ens33" >> $cfg_file
    sudo sed -i '/iface ens33 inet dhcp/d' $cfg_file
    sudo echo "iface ens33 inet static" >> $cfg_file
    sudo echo "address $new_ip" >> $cfg_file
    sudo echo "netmask 255.255.255.0" >> $cfg_file
    sudo echo "gateway $(ip route | awk '/^default via /{print $3}')" >> $cfg_file
      
    # 重启网络服务
    sudo systemctl restart networking.service >> $LOG_FILE 2>&1
  
    # 等待网络服务重启完成
    sleep 2
  else
    echo "Unsupported Deepin version: $deepin_version"
    exit 1
  fi
else
  # CentOS系统
  cfg_file="/etc/sysconfig/network-scripts/ifcfg-ens33"
  sudo sed -i '/BOOTPROTO/d' $cfg_file
  sudo echo "BOOTPROTO=static" >> $cfg_file
  sudo sed -i '/IPADDR/d' $cfg_file
  sudo echo "IPADDR=$new_ip" >> $cfg_file
  sudo sed -i '/NETMASK/d' $cfg_file
  sudo echo "NETMASK=255.255.255.0" >> $cfg_file
  sudo systemctl restart network >> $LOG_FILE 2>&1
  
  # 等待网络服务重启完成
  sleep 2
fi

# 记录修改后的IP信息到日志文件
echo "After modification:" >> $LOG_FILE
ip addr show dev ens33 >> $LOG_FILE

# 输出提示信息，让用户查询当前IP地址
case $lang in
  "zh_CN")
    echo "IP 地址设置成功！"
    echo "请使用以下命令查询当前 IP 地址："
    echo "ip addr show dev ens33"
    ;;
  "en_US")
    echo "IP address updated successfully!"
    echo "Please use the following command to check your current IP address:"
    echo "ip addr show dev ens33"
    ;;
  "ja_JP")
    echo "IP アドレスが正常に更新されました！"
    echo "以下のコマンドを使用して、現在の IP アドレスを確認してください。"
    echo "ip addr show dev ens33"
    ;;
esac

# 提示用户可以输入reboot命令重启系统
while true; do
  case $lang in
    "zh_CN")
      read -p "是否立即重启？（y/n）：" yn
      ;;
    "en_US")
      read -p "Do you want to reboot now? (y/n): " yn
      ;;
    "ja_JP")
      read -p "今すぐ再起動しますか？（y/n）：" yn
      ;;
  esac

  case $yn in
    [Yy]* )
      echo "正在重启系统..."
      sudo reboot
      ;;
    [Nn]* )
      echo "ipModify 已退出。"
      exit
      ;;
    * )
      case $lang in
        "zh_CN")
          echo "请输入 y 或 n。"
          ;;
        "en_US")
          echo "Please answer yes or no."
          ;;
        "ja_JP")
          echo "はいまたはいいえで回答してください。"
          ;;
      esac
      ;;
  esac
done


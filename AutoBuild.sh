# 打包脚本

#!/bin/bash


# Target

#转为小写函数
function lowercase(){
echo $1 | tr '[A-Z]' '[a-z]'
}

#取得计算机指令MD5值函数
function mdd5(){
echo -n $1|md5
}
#取得计算机指令取随机数函数
function randomNumber(){
echo "0.$(($RANDOM+10000000000000001))"
}
#计算Nodejs签名参数
function signCode(){
code="source=$1&agent=$2&time=$3&random=$4"
echo $(mdd5 $code)
}


#Nodejs 文件传输来源
source="app"
#Nodejs 文件类型
agent="ios"
#Nodejs 文件上传用户名,上传到的网站地址
username=""
#Nodejs 文件上传密码
password=""
#Nodejs 文件上传Post路径
uploadPath=""
#苹果账号id
AppleID=""
#苹果账号密码
AppleIDPWD=""

#设置项目根路径
project_path="$(pwd)"
#项目名称
project_name=""

# #指定打包的scheme_name，由外界输入
# scheme_name="$1"

#指定项目地址
workspace_path="$project_path/${project_name}.xcworkspace"

#指定输出路径，此处scheme_name还未复值，去掉
output_path="${project_path}/BUILD"

# app配置文件地址
InfoPlist="$project_path/${project_name}/Info.plist"

rm -rf ${output_path}
mkdir -p ${output_path}

case "$1" in
    "IpaForStore")
        #指定打包的scheme_name
        scheme_name="IpaRelease"
        ## 构建配置
        buildConfiguration="Release";;
    "IpaRelease")
        #指定打包的scheme_name
        scheme_name="IpaRelease"
        ## 构建配置
        buildConfiguration="Release";;
    "IpaTest")
        #指定打包的scheme_name
        scheme_name="IpaTest"
        ## 构建配置
        buildConfiguration="AdhocTest";;
    "IpaBeta")
        #指定打包的scheme_name
        scheme_name="IpaBeta"
        ## 构建配置
        buildConfiguration="AdhocBeta";;
    *)
        echo "您打包的项目不存在，请仔细检查Scheme Name"
        exit;;
esac

# app配置文件地址
InfoPlist="$project_path/${project_name}/Info.plist"

# 上传AppStore
if [ "$1" = "IpaForStore" ]
then 
    #导出ipa 所需plist
    ExportOptionsPlist="$project_path/AppStoreExportOptionsPlist.plist"
    # 打包使用的证书
    CODE_SIGN_IDENTITY="iPhone Distribution: Hangzhou MRJ Internet S&T Co., Ltd. (58VA3BYFVV)"
    PROVISIONING_PROFILE_NAME="Ipa Distribution Profile"
    # # 指定打包所使用的输出方式，目前支持app-store, package, ad-hoc, enterprise, development, 和developer-id，即xcodebuild的method参数
    # export_method='app-store'
else
    #导出ipa 所需plist
    ExportOptionsPlist="$project_path/ADHOCExportOptionsPlist.plist"
    # 打包使用的证书
    CODE_SIGN_IDENTITY="iPhone Distribution: Hangzhou MRJ Internet S&T Co., Ltd. (58VA3BYFVV)"
    PROVISIONING_PROFILE_NAME="Ipa AdHoc Profile"
    # app版本号
    CFBundleShortVersionString=$(/usr/libexec/PlistBuddy -c "print CFBundleShortVersionString" ${InfoPlist})
    # 构建版本号
    CFBundleVersion=$(/usr/libexec/PlistBuddy -c "print CFBundleVersion" ${InfoPlist})
    # 修改构建版本号
    CFBundleVersion="${CFBundleShortVersionString}--${CFBundleVersion}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${CFBundleVersion}" $InfoPlist
    # # 指定打包所使用的输出方式，目前支持app-store, package, ad-hoc, enterprise, development, 和developer-id，即xcodebuild的method参数
    # export_method='development'
fi

#指定输出归档文件地址
archive_path="$output_path/${scheme_name}.xcarchive"
#指定输出ipa名称
ipa_path="$output_path/${scheme_name}.ipa"

SECONDS=0

if [[ ! -d "$workspace_path" ]]; then
echo "路径："$workspace_path
echo "未找到.xcworkspace文件，已终止!!!"
exit
fi

# xcpretty 设置
export LC_ALL=en_US.UTF-8

#指定打包所使用的输出方式，目前支持app-store, package, ad-hoc, enterprise, development, 和developer-id，即xcodebuild的method参数
# export_method='development'

#输出设定的变量值
echo "=================AutoPackageBuilder==============="
echo "begin package at ${now}"
echo "workspace path: ${workspace_path}"
echo "scheme name: ${scheme_name}"
echo "out path: ${output_path}"
echo "archive path: ${archive_path}"
echo "ipa path: ${ipa_path}"
echo "InfoPlist: ${InfoPlist}"
echo "CFBundleShortVersionString: ${CFBundleShortVersionString}"
echo "CFBundleVersion: ${CFBundleVersion}"
echo "commit msg: $1"

echo "准备开始打ipa包...................."

echo "第一步，进入项目工程文件: $project_path"

cd ${project_path}


echo "第二步，执行build clean命令"

xcodebuild clean

echo "第三步，执行编译生成.app命令"

echo "Building...."

xcodebuild archive -workspace ${workspace_path} -scheme ${scheme_name} -archivePath ${archive_path} -configuration ${buildConfiguration} CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" PROVISIONING_PROFILE="${PROVISIONING_PROFILE_NAME}" | xcpretty

echo "Ipaing...."

#生成ipa包
xcodebuild -exportArchive -archivePath ${archive_path} -exportOptionsPlist ${ExportOptionsPlist} -exportPath ${output_path} | xcpretty



#输出总用时
echo "==================>Finished. Total time: ${SECONDS}s"

echo "Upload Ipa......"
# 上传AppStore
if [ "$1" = "IpaForStore" ]
then 
    altoolPath="/Applications/Xcode.app/Contents/Applications/Application Loader.app/Contents/Frameworks/ITunesSoftwareService.framework/Versions/A/Support/altool"
    #validate
    "$altoolPath" --validate-app -f "$ipa_path" -u "$AppleID" -p "$AppleIDPWD" -t ios --output-format xml 
    #upload
    "$altoolPath" --upload-app -f "$ipa_path" -u "$AppleID" -p "$AppleIDPWD" -t ios --output-format xml
else
    # 上传cola
    time=$(date +%Y%m%d%H%M%S)
    random=$(randomNumber)
    sign=$(signCode $source $agent $time $random)
    result=$(curl -H "source:$source" -H "agent:$agent" -H "time:$time" -H "random:$random" -H "sign:$sign"  -F "file=@${ipa_path}" -F "username=$username" -F "password=$password" "$uploadPath")
    echo "$result"
fi

exit

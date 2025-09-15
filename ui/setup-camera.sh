#!/bin/bash

# STM32MP257 OV5645 智能摄像头拍照脚本
# 自动适配重启后变化的设备号和管道映射
# 支持1280x960分辨率拍照

OUTPUT_FILE="${1:-photo_$(date +%Y%m%d_%H%M%S).rgb}"

echo "正在检测摄像头设备和管道..."

# 检查OV5645是否被检测到
if ! dmesg | grep -q "OV5645 detected"; then
    echo "错误: 未检测到OV5645摄像头"
    exit 1
fi

# 查找dcmipp_dump_capture对应的video设备号
# 这个管道支持1280x960分辨率
DUMP_CAPTURE_DEVICE=""
MEDIA_DEVICE=""

# 自动查找包含dcmipp的media设备
for media_dev in /dev/media*; do
    if media-ctl -d $media_dev -p 2>/dev/null | grep -q "dcmipp_dump_capture"; then
        MEDIA_DEVICE="$media_dev"
        break
    fi
done

if [ -z "$MEDIA_DEVICE" ]; then
    echo "错误: 无法找到dcmipp媒体设备"
    exit 1
fi

echo "找到媒体设备: $MEDIA_DEVICE"

# 从媒体管道中找到dcmipp_dump_capture对应的video设备
DUMP_CAPTURE_DEVICE=$(media-ctl -d $MEDIA_DEVICE -p | grep -A3 "dcmipp_dump_capture" | grep "device node name" | awk '{print $4}')

if [ -z "$DUMP_CAPTURE_DEVICE" ]; then
    echo "错误: 无法找到dcmipp_dump_capture设备"
    exit 1
fi

echo "找到dump capture设备: $DUMP_CAPTURE_DEVICE"

# 验证I2C通信
if ! i2cdetect -y 1 | grep -E "30:.*UU" >/dev/null 2>&1; then
    echo "警告: I2C地址0x3c处设备状态异常"
else
    echo "I2C通信正常"
fi

echo "配置摄像头管道..."

# 配置媒体管道 - 这个配置很重要，确保整个数据流路径正确
media-ctl -d $MEDIA_DEVICE --set-v4l2 '"ov5645 1-003c":0[fmt:UYVY8_1X16/1280x960]'
media-ctl -d $MEDIA_DEVICE --set-v4l2 '"48020000.csi":1[fmt:UYVY8_1X16/1280x960]'
media-ctl -d $MEDIA_DEVICE --set-v4l2 '"dcmipp_input":0[fmt:UYVY8_1X16/1280x960]'
media-ctl -d $MEDIA_DEVICE --set-v4l2 '"dcmipp_dump_postproc":0[fmt:UYVY8_1X16/1280x960]'
media-ctl -d $MEDIA_DEVICE --set-v4l2 '"dcmipp_dump_postproc":1[fmt:RGB888_1X24/1280x960]'
media-ctl -d $MEDIA_DEVICE --link '"dcmipp_input":1->"dcmipp_dump_postproc":0[1]'

# 配置video设备为1280x960 RGB3
v4l2-ctl -d $DUMP_CAPTURE_DEVICE --set-fmt-video=width=1280,height=960,pixelformat=RGB3

echo "正在拍摄照片到 $OUTPUT_FILE ..."

# 执行拍照
v4l2-ctl -d $DUMP_CAPTURE_DEVICE --stream-mmap --stream-to="$OUTPUT_FILE" --stream-count=1

if [ -f "$OUTPUT_FILE" ]; then
    FILE_SIZE=$(stat -c%s "$OUTPUT_FILE")
    EXPECTED_SIZE=$((1280*960*2))

    echo "拍摄完成！"
    echo "你如果想要转成png的话，可以使用下面这个命令，默认开发板性能有限，当然你也可以直接在开发板里转也行，随便你，我这边就不写了"
    echo "ffmpeg -f rawvideo -pix_fmt uyvy422 -s 1280x960 -i '$OUTPUT_FILE' output.png"
else
    echo "拍摄失败！"
    exit 1
fi
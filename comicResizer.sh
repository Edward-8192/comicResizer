#!/usr/bin/env bash

# 建議在腳本一開始時檢查所需的外部程式是否已安裝：
# p7zip-full, imagemagick (mogrify、identify), zip, unrar, ditto (macOS) 等

set -uo pipefail  # 避免意外錯誤後繼續執行，並讓未定義變數、管線錯誤立即中斷 => 移除 -e, 修改為不會中斷

IFS=$'\n'
CURRENTDATE="$(date +"%Y-%m-%d")"
FOLDER="resize-$CURRENTDATE"
FOLDERNAMEWITHTIME=$(date +%Y%m%d%H%M%S)
mkdir -p "$FOLDER"
TMP_DIR="./tmp"
mkdir -p "$TMP_DIR"
PROCESSED_DIR="./resizedOrigi-$FOLDERNAMEWITHTIME"
mkdir -p "$PROCESSED_DIR"

RESIZEDCOUNT=0
ERRORCOUNT=0
START_TIME=$SECONDS


#---------------------------------------
# 共用函式：將暫存資料夾內所有影像處理後再打包成 zip
#---------------------------------------
function process_images_and_zip() {
  local src_dir="$1"
  local out_name="$2"   # 壓縮後的檔名（不含路徑）

  # 1. 針對 jpg、png、webp 進行尺寸與格式處理
  find "$src_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) -print -exec bash -c '
    SIZE=$(identify -format %h "$1")
    if [ "$SIZE" -gt 2800 ]; then
      mogrify -resize x2800 -quality 80 "$1"
    else
      mogrify -quality 80 "$1"
    fi
  ' _ {} \;

  find "$src_dir" -type f -iname '*.png' -print -exec bash -c '
    SIZE=$(identify -format %h "$1")
    if [ "$SIZE" -gt 2800 ]; then
      mogrify -format jpg -resize x2800 -quality 80 "$1"
    else
      mogrify -format jpg -quality 80 "$1"
    fi
  ' _ {} \;

  find "$src_dir" -type f -iname '*.webp' -print -exec bash -c '
    SIZE=$(identify -format %h "$1")
    if [ "$SIZE" -gt 2800 ]; then
      mogrify -format jpg -resize x2800 -quality 80 "$1"
    else
      mogrify -format jpg -quality 80 "$1"
    fi
  ' _ {} \;

  # 2. 移除不必要的檔案
  find "$src_dir" -type f \( -iname '*.png' -o -iname '*.webp' -o -iname '*.txt' -o -iname '*.url' \) -exec rm -f {} \;

  # 3. 打包成 zip，放到最終輸出資料夾
  (
    cd "$src_dir"
    zip -0 -r "../../$FOLDER/$out_name.zip" ./*
  )
}


#---------------------------------------
# 解壓並處理函式：針對每種壓縮格式使用不同解壓指令
#---------------------------------------
function process_comic_archive() {
  local file="$1"
  local ext="$2"

  local base_name="${file%.$ext}"
  local target_dir="$TMP_DIR/$base_name"

  mkdir -p "$target_dir"
  echo "Processing: $file"

  # 嘗試解壓縮，若失敗，移到 Error 資料夾並跳過
  if ! {
    case "$ext" in
      7z)
        7z x "$file" -o"$target_dir"
        ;;
      rar|cbr)
        unrar x -y "$file" "$target_dir"
        ;;
      zip|cbz)
        if command -v ditto >/dev/null 2>&1; then
          ditto -x -k --sequesterRsrc -rsrc "$file" "$target_dir"
        else
          unzip -q "$file" -d "$target_dir"
        fi
        ;;
    esac
  }; then
    echo "❌ Error: Failed to extract $file. Moving to Error folder."
    mkdir -p "./Error"
    mv "$file" "./Error/"
    return 1
  fi

  # 正常流程：處理圖片與重新打包
  process_images_and_zip "$target_dir" "$base_name"
  mv "$file" "$PROCESSED_DIR"
}



#---------------------------------------
# 主流程：針對各種壓縮檔案做處理
#---------------------------------------
for ext in 7z rar zip cbr cbz; do
  shopt -s nullglob
  for file in *."$ext"; do
    [ -f "$file" ] || continue
    if process_comic_archive "$file" "$ext"; then
      ((RESIZEDCOUNT++))
    else
      echo "⚠️  Skip failed file: $file"
      ((ERRORCOUNT++))
    fi
  done
  shopt -u nullglob
done


#---------------------------------------
# 收尾
#---------------------------------------
COMPLETEDATE="$(date)"
echo ""
echo "---------------------------------------------------------------------"
echo "Resize completed: $RESIZEDCOUNT items at $COMPLETEDATE!"
echo "Resize failed: $ERRORCOUNT items"
echo "---------------------------------------------------------------------"
echo "Output folder: $FOLDER"
echo "---------------------------------------------------------------------"
echo "Resized original files folder: $PROCESSED_DIR"
echo "You can delete original files if you checked resize results."
echo "---------------------------------------------------------------------"

ELAPSED=$(( SECONDS - START_TIME ))
echo "Elapsed Time: $ELAPSED seconds"
echo "---------------------------------------------------------------------"
echo ""

# 清理暫存資料
rm -rf "$TMP_DIR"

unset IFS

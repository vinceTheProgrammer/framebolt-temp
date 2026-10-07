mkdir -p res/android/res/{mipmap-mdpi,mipmap-hdpi,mipmap-xhdpi,mipmap-xxhdpi,mipmap-xxxhdpi}
magick res/icons/framebolt.png -resize 48x48   res/android/res/mipmap-mdpi/ic_launcher.png
magick res/icons/framebolt.png -resize 72x72   res/android/res/mipmap-hdpi/ic_launcher.png
magick res/icons/framebolt.png -resize 96x96   res/android/res/mipmap-xhdpi/ic_launcher.png
magick res/icons/framebolt.png -resize 144x144 res/android/res/mipmap-xxhdpi/ic_launcher.png
magick res/icons/framebolt.png -resize 192x192 res/android/res/mipmap-xxxhdpi/ic_launcher.png
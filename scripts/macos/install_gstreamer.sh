echo "🍎 Installing GStreamer for macOS..."
mkdir -p gst-installer
cd gst-installer

echo "Downloading GStreamer runtime..."
curl -L "https://gstreamer.freedesktop.org/data/pkg/osx/1.26.7/gstreamer-1.0-1.26.7-universal.pkg" -o gstreamer-runtime.pkg

echo "Downloading GStreamer devel..."
curl -L "https://gstreamer.freedesktop.org/data/pkg/osx/1.26.7/gstreamer-1.0-devel-1.26.7-universal.pkg" -o gstreamer-devel.pkg

echo "Installing both packages..."
sudo installer -pkg gstreamer-runtime.pkg -target /
sudo installer -pkg gstreamer-devel.pkg -target /

echo "✅ GStreamer framework installed to /Library/Frameworks/"
cd ..
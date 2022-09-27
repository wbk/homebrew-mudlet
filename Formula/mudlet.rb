class Mudlet < Formula
  desc "Multi-User Dungeon client"
  homepage "https://www.mudlet.org/"
  url "https://www.mudlet.org/download/Mudlet-4.16.0.tar.xz"
  sha256 "aa36c80e6e75761f834032f9ca7573b3a7991998afe90017c535be5c523af30b"
  license "GPL-2.0-or-later"

  depends_on "boost" => :build
  depends_on "cmake" => :build
  depends_on "ccache" => :build
  depends_on "pkg-config" => :build

  depends_on "hunspell"
  depends_on "libzip"
  depends_on "lua@5.1"
  depends_on "luarocks"
  depends_on "pcre"
  depends_on "pugixml"
  depends_on "qt5"
  depends_on "sqlite"
  depends_on "yajl"

  resource "lrexlib-pcre" do
    url "https://luarocks.org/lrexlib-pcre-2.9.1-1.src.rock"
    sha256 "9f9a331ae624bee293f167922763706147361c0459e26b9243b9746547c84a67"
  end
  
  resource "luasql-sqlite3" do
    url "https://luarocks.org/luasql-sqlite3-2.6.0-1.rockspec"
    sha256 "02dc4a03206369efc0af0b3db44586c0adae543b1d6f659464742ae6b4fd6270"
  end
  
  resource "luautf8" do
    url "https://luarocks.org/luautf8-0.1.3-1.src.rock"
    sha256 "88c456bc0f00d28201b33551d83fa6e5c3ae6025aebec790c37afb317290e4fa"
  end
  
  resource "lua-yajl" do
    url "https://luarocks.org/lua-yajl-2.0-1.src.rock"
    sha256 "8e5c5bde4ae4aac336c5ce6da2aef94bf4f69f37e921d718647914bd5328552f"
  end
  
  resource "luafilesystem" do
    url "https://luarocks.org/luafilesystem-1.8.0-1.src.rock"
    sha256 "576270a55752894254c2cba0d49d73595d37ec4ea8a75e557fdae7aff80e19cf"
  end
  
  resource "lua-zip" do
    url "https://luarocks.org/lua-zip-0.2-0.src.rock"
    sha256 "106cbef9aaac1742824bead6d2373adfe1f829a536eb0d3435d53ecf9af5b253"
  end

  patch :DATA

  def install
    # Lua package handling ripped shamelessly from sile.rb

    lua = Formula["lua@5.1"]
    luaversion = lua.version.major_minor
    vendor = libexec/"vendor"
    luashare = vendor/"share/lua/#{luaversion}"
    lualib = vendor/"lib/lua/#{luaversion}"
    contents = libexec/"Mudlet.app/Contents"
    app_bin = contents/"MacOS"

    luarocks_args = %W[
      PCRE_DIR=#{Formula["pcre"].opt_prefix}
      SQLITE_DIR=#{Formula["sqlite"].opt_prefix}
      YAJL_DIR=#{Formula["yajl"].opt_prefix}
      ZIP_DIR=#{Formula["libzip"].opt_prefix}
      --lua-version=5.1
      --tree=#{vendor}
      --lua-dir=#{lua.opt_prefix}
    ]

    paths = %W[
      /?.lua
      #{luashare}/?/init.lua
      #{luashare}/lxp/?.lua
    ]

    cpaths = %W[
      "#{lualib}/?.so"
    ]

    ENV["LUA_PATH"] = paths.join(";")
    ENV["LUA_CPATH"] = cpaths.join(";")

    ENV.prepend "CPPFLAGS", "-I#{lua.opt_include}/lua"
    ENV.prepend "LDFLAGS", "-L#{lua.opt_lib}"

    resources.each do |r|
      r.stage do
        rock = Pathname.pwd.children(false).first
        unpack_dir = Utils.safe_popen_read("luarocks", "unpack", rock).split("\n")[-2]

        spec = "#{r.name}-#{r.version}.rockspec"
        cd(unpack_dir) { system "luarocks", "make", *luarocks_args, spec }
      end
    end

    cmake_args = %W[
      -S .
      -B build
      -DCMAKE_INSTALL_RPATH=#{libexec}
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    ] + std_cmake_args(install_libdir: libexec)

    system "cmake", *cmake_args
    system "make", "-C", "build"

    system "make", "-C", "build", "install"

    # libQsLog.dylib's install location is hardcoded to lib, but it belongs in libexec
    (lib/"libQsLog.dylib").rename libexec/"libQsLog.dylib"

    libexec.install "build/src/mudlet.app" => "Mudlet.app"
    libexec.install Dir["3rdparty/cocoapods/Pods/Sparkle/Sparkle.framework"]
    libexec.install Dir["3rdparty/discord/rpc/lib/libdiscord-rpc.dylib"]
    luashare.install Dir["3rdparty/lcf"]

    plist_entries = [
      "Add CFBundleDisplayName string Mudlet",

      # Sparkle settings, see https://sparkle-project.org/documentation/customization/#infoplist-settings
      # Because homebrew handles its own updates, I turned off as much as I could via the Plist
      "Add SUFeedURL string https://feeds.dblsqd.com/MKMMR7HNSP65PquQQbiDIw/release/mac/x86_64/appcast",
      "Add SUEnableAutomaticChecks bool false",
      "Add SUAllowsAutomaticUpdates bool false",
      "Add SUAutomaticallyUpdate bool false",

      # Enable HiDPI support
      "Add NSPrincipalClass string NSApplication",
      "Add NSHighResolutionCapable string true"
    ]

    plist_entries.each do |entry|
      system "/usr/libexec/PlistBuddy", "-c", entry, contents/"Info.plist"
    end

    lua_dynlibs = %W[
      #{lualib}/yajl.so
      #{lualib}/rex_pcre.so
      #{lualib}/luasql
      #{lualib}/brimworks
      #{lualib}/lfs.so
      #{lualib}/lua-utf8.so
    ]

    lua_dynlibs.each { |lua_lib| app_bin.install_symlink lua_lib }

    (bin/"mudlet").write <<~EOS
      #!/bin/bash
      open "#{libexec/"Mudlet.app"}" "$@"
    EOS
  end

  test do
    system "#{bin}/mudlet", "--version"
  end
end

__END__
diff --git a/src/TLuaInterpreter.cpp b/src/TLuaInterpreter.cpp
index 7b3a984..0ae881b 100644
--- a/src/TLuaInterpreter.cpp
+++ b/src/TLuaInterpreter.cpp
@@ -15390,6 +15390,11 @@ void TLuaInterpreter::initLuaGlobals()
     // binary directory for both modules and binary libraries:
     additionalCPaths << qsl("%1/?.so").arg(appPath);
     additionalLuaPaths << qsl("%1/?.lua").arg(appPath);
+
+    // Luarocks installs rocks locally for developers, even with sudo
+    additionalCPaths << qsl("%1/.luarocks/lib/lua/5.1/?.so").arg(QStandardPaths::standardLocations(QStandardPaths::HomeLocation).first());
+    additionalLuaPaths << qsl("%1/.luarocks/share/lua/5.1/?.lua;%1/.luarocks/share/lua/5.1/?/init.lua").arg(QStandardPaths::standardLocations(QStandardPaths::HomeLocation).first());
+
 #elif defined(Q_OS_WIN32) && defined(INCLUDE_MAIN_BUILD_SYSTEM)
     // For CI builds or users/developers using the setup-windows-sdk.ps1 method:
     additionalCPaths << qsl("C:\\Qt\\Tools\\mingw730_32\\lib\\lua\\5.1\\?.dll");

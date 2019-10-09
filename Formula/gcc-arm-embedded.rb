class GccArmEmbedded < Formula
    desc "The GNU Compiler Collection - cross compiler for ARM EABI (bare-metal) target"
    homepage "https://gcc.gnu.org/"
    url "https://ftp.gnu.org/gnu/gcc/gcc-9.2.0/gcc-9.2.0.tar.xz"
    mirror "https://ftpmirror.gnu.org/gcc/gcc-9.2.0/gcc-9.2.0.tar.xz"
    sha256 "ea6ef08f121239da5695f76c9b33637a118dcf63e24164422231917fa61fb206"
    head "https://gcc.gnu.org/git/gcc.git"

    depends_on "gmp"
    depends_on "isl"
    depends_on "libmpc"
    depends_on "mpfr"

    # GCC bootstraps itself, so it is OK to have an incompatible C++ stdlib
    cxxstdlib_check :skip

    # Fix system headers for Catalina SDK
    # (otherwise __OSX_AVAILABLE_STARTING ends up undefined)
    if DevelopmentTools.clang_build_version >= 1100
        patch do
        url "https://raw.githubusercontent.com/Homebrew/formula-patches/b8b8e65e/gcc/9.2.0-catalina.patch"
        sha256 "0b8d14a7f3c6a2f0d2498526e86e088926671b5da50a554ffa6b7f73ac4f132b"
        end
    end

    def version_suffix
        if build.head?
          "HEAD"
        else
          version.to_s.slice(/\d/)
        end
      end

    def install
    # GCC will suffer build errors if forced to use a particular linker.
    ENV.delete "LD"

    languages = %w[c c++]

    osmajor = `uname -r`.split(".").first
    # add  back in
    pkgversion = "Homebrew GCC #{pkg_version} #{build.used_options*" "}".strip

    target = "arm-none-eabi"

    print prefix

    # This is a combination of Homebrew gcc flags and flags from Arch's arm-none-eabi-gcc package:
    # https://git.archlinux.org/svntogit/community.git/tree/repos/community-x86_64/PKGBUILD?h=packages/arm-none-eabi-gcc
    args = %W[
      --target=#{target}
      --build=x86_64-apple-darwin#{osmajor}
      --prefix=#{prefix}
      --libdir=#{lib}/gcc/#{version_suffix}
      --disable-nls
      --enable-checking=release
      --enable-languages=#{languages.join(",")}
      --program-suffix=-#{version_suffix}
      --enable-plugins
      --disable-decimal-float
      --disable-libffi
      --disable-libgomp
      --disable-libmudflap
      --disable-libquadmath
      --disable-libssp
      --disable-libstdcxx-pch
      --disable-nls
      --disable-shared
      --disable-threads
      --disable-tls
      --with-gnu-as
      --with-gnu-ld
      --with-system-zlib
      --with-newlib
      --with-headers=/usr/#{target}/include
      --with-python-dir=share/gcc-#{target}
      --with-gmp
      --with-mpfr
      --with-mpc
      --with-isl
      --with-libelf
      --enable-gnu-indirect-function
      --with-multilib-list=rmprofile
      --with-system-zlib
      --with-pkgversion=#{pkgversion}
      --with-bugurl=https://github.com/Homebrew/homebrew-core/issues
    ]

    args << "--with-host-libstdcxx=\"-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm\""


    # Xcode 10 dropped 32-bit support
    args << "--disable-multilib" if DevelopmentTools.clang_build_version >= 1000

    # Ensure correct install names when linking against libgcc_s;
    # see discussion in https://github.com/Homebrew/legacy-homebrew/pull/34303
    inreplace "libgcc/config/t-slibgcc-darwin", "@shlib_slibdir@", "#{HOMEBREW_PREFIX}/lib/gcc/#{version_suffix}"

    if !MacOS::CLT.installed?
        # For Xcode-only systems, we need to tell the sysroot path
        args << "--with-native-system-header-dir=/usr/include"
        args << "--with-sysroot=#{MacOS.sdk_path}"
    elsif MacOS.version >= :mojave
        # System headers are no longer located in /usr/include
        args << "--with-native-system-header-dir=/usr/include"
        args << "--with-sysroot=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
    end
    mkdir "build-gcc" do
        print args
      system "../configure", *args
      ENV["CFLAGS_FOR_TARGET"] = "-g -Os -ffunction-sections -fdata-sections"
      ENV["CXXFLAGS_FOR_TARGET"] = "-g -Os -ffunction-sections -fdata-sections"
      # Use -headerpad_max_install_names in the build,
      # otherwise updated load commands won't fit in the Mach-O header.
      # This is needed because `gcc` avoids the superenv shim.
      system "make", "BOOT_LDFLAGS=-Wl,-headerpad_max_install_names", "INHIBIT_LIBC_CFLAGS='-DUSE_TM_CLONE_REGISTRY=0'" 
    end
    mkdir "build-gcc-nano" do
      system "../configure", *args

      ENV["CFLAGS_FOR_TARGET"] = "-g -Os -ffunction-sections -fdata-sections -fno-exceptions"
      ENV["CXXFLAGS_FOR_TARGET"] = "-g -Os -ffunction-sections -fdata-sections -fno-exceptions"

      # Use -headerpad_max_install_names in the build,
      # otherwise updated load commands won't fit in the Mach-O header.
      # This is needed because `gcc` avoids the superenv shim.
      system "make", "BOOT_LDFLAGS=-Wl,-headerpad_max_install_names"
    end

    # Handle conflicts between GCC formulae and avoid interfering
    # with system compilers.
    # Rename man7.
    Dir.glob(man7/"*.7") { |file| add_suffix file, version_suffix }
    # Even when we disable building info pages some are still installed.
    info.rmtree
end

    test do
        system "false"
    end
end
  
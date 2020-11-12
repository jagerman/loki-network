local default_deps_base='libsystemd-dev python3-dev libuv1-dev libunbound-dev nettle-dev libssl-dev libevent-dev libsqlite3-dev';
local default_deps_nocxx='libsodium-dev ' + default_deps_base; // libsodium-dev needs to be >= 1.0.18
local default_deps='g++ ' + default_deps_nocxx; // g++ sometimes needs replacement
local default_windows_deps='mingw-w64 zip nsis';


local submodules = {
    name: 'submodules',
    image: 'drone/git',
    commands: ['git fetch --tags', 'git submodule update --init --recursive --depth=1']
};

local apt_get_quiet = 'apt-get -o=Dpkg::Use-Pty=0 -q';

// Regular build on a debian-like system:
local debian_pipeline(name, image,
        arch='amd64',
        deps=default_deps,
        build_type='Release',
        lto=false,
        werror=true,
        cmake_extra='',
        extra_cmds=[],
        loki_repo=false,
        allow_fail=false) = {
    kind: 'pipeline',
    type: 'docker',
    name: name,
    platform: { arch: arch },
    trigger: { branch: { exclude: ['debian/*', 'ubuntu/*'] } },
    steps: [
        submodules,
        {
            name: 'build',
            image: image,
            [if allow_fail then "failure"]: "ignore",
            environment: { SSH_KEY: { from_secret: "SSH_KEY" } },
            commands: [
                'echo "Building on ${DRONE_STAGE_MACHINE}"',
                'echo "man-db man-db/auto-update boolean false" | debconf-set-selections',
                apt_get_quiet + ' update',
                apt_get_quiet + ' install -y eatmydata',
                ] + (if loki_repo then [
                    'eatmydata ' + apt_get_quiet + ' install -y lsb-release',
                    'cp contrib/deb.loki.network.gpg /etc/apt/trusted.gpg.d',
                    'echo deb http://deb.loki.network $$(lsb_release -sc) main >/etc/apt/sources.list.d/loki.network.list',
                    'eatmydata ' + apt_get_quiet + ' update'
                    ] else []
                ) + [
                'eatmydata ' + apt_get_quiet + ' dist-upgrade -y',
                'eatmydata ' + apt_get_quiet + ' install -y gdb cmake git ninja-build pkg-config ccache ' + deps,
                'mkdir build',
                'cd build',
                'cmake .. -G Ninja -DCMAKE_CXX_FLAGS=-fdiagnostics-color=always -DCMAKE_BUILD_TYPE='+build_type+' ' +
                    (if werror then '-DWARNINGS_AS_ERRORS=ON ' else '') +
                    '-DWITH_LTO=' + (if lto then 'ON ' else 'OFF ') +
                cmake_extra,
                'ninja -v',
                '../contrib/ci/drone-gdb.sh ./test/testAll --gtest_color=yes',
                '../contrib/ci/drone-gdb.sh ./test/catchAll --use-colour yes',
            ] + extra_cmds,
        }
    ],
};

// windows cross compile on alpine linux
local windows_cross_pipeline(name, image,
        arch='amd64',
        build_type='Release',
        lto=false,
        werror=false,
        cmake_extra='',
        toolchain='32',
        extra_cmds=[],
        allow_fail=false) = {
    kind: 'pipeline',
    type: 'docker',
    name: name,
    platform: { arch: arch },
    trigger: { branch: { exclude: ['debian/*', 'ubuntu/*'] } },
    steps: [
        submodules,
        {
            name: 'build',
            image: image,
            [if allow_fail then "failure"]: "ignore",
            environment: { SSH_KEY: { from_secret: "SSH_KEY" }, WINDOWS_BUILD_NAME: toolchain+"bit" },
            commands: [
                'echo "Building on ${DRONE_STAGE_MACHINE}"',
                'echo "man-db man-db/auto-update boolean false" | debconf-set-selections',
                apt_get_quiet + ' update',
                apt_get_quiet + ' install -y eatmydata',
                'eatmydata ' + apt_get_quiet + ' install -y build-essential cmake git ninja-build pkg-config ccache g++-mingw-w64-x86-64-posix nsis zip',
                'update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix',
                'update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix',
                'git clone https://github.com/despair86/libuv.git win32-setup/libuv',
                'mkdir build',
                'cd build',
                'cmake .. -G Ninja -DCMAKE_CROSSCOMPILE=ON -DCMAKE_EXE_LINKER_FLAGS=-fstack-protector -DLIBUV_ROOT=$PWD/../win32-setup/libuv -DCMAKE_CXX_FLAGS=-fdiagnostics-color=always -DCMAKE_TOOLCHAIN_FILE=../contrib/cross/mingw'+toolchain+'.cmake -DCMAKE_BUILD_TYPE='+build_type+' ' +
                    (if werror then '-DWARNINGS_AS_ERRORS=ON ' else '') +
                    (if lto then '' else '-DWITH_LTO=OFF ') +
                    "-DBUILD_STATIC_DEPS=ON -DDOWNLOAD_SODIUM=ON -DBUILD_PACKAGE=ON -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DNATIVE_BUILD=OFF -DSTATIC_LINK=ON" +
                cmake_extra,
                'ninja -v package',
            ] + extra_cmds,
        }
    ],
};

// Builds a snapshot .deb on a debian-like system by merging into the debian/* or ubuntu/* branch
local deb_builder(image, distro, distro_branch, arch='amd64', loki_repo=true) = {
    kind: 'pipeline',
    type: 'docker',
    name: 'DEB (' + distro + (if arch == 'amd64' then '' else '/' + arch) + ')',
    platform: { arch: arch },
    environment: { distro_branch: distro_branch, distro: distro },
    steps: [
        submodules,
        {
            name: 'build',
            image: image,
            failure: 'ignore',
            environment: { SSH_KEY: { from_secret: "SSH_KEY" } },
            commands: [
                'echo "Building on ${DRONE_STAGE_MACHINE}"',
                'echo "man-db man-db/auto-update boolean false" | debconf-set-selections'
                ] + (if loki_repo then [
                    'cp contrib/deb.loki.network.gpg /etc/apt/trusted.gpg.d',
                    'echo deb http://deb.loki.network $${distro} main >/etc/apt/sources.list.d/loki.network.list'
                ] else []) + [
                apt_get_quiet + ' update',
                apt_get_quiet + ' install -y eatmydata',
                'eatmydata ' + apt_get_quiet + ' install -y git devscripts equivs ccache git-buildpackage python3-dev',
                |||
                    # Look for the debian branch in this repo first, try upstream if that fails.
                    if ! git checkout $${distro_branch}; then
                        git remote add --fetch upstream https://github.com/loki-project/loki-network.git &&
                        git checkout $${distro_branch}
                    fi
                |||,
                # Tell the merge how to resolve conflicts in the source .drone.jsonnet (we don't
                # care about it at all since *this* .drone.jsonnet is already loaded).
                'git config merge.ours.driver true',
                'echo .drone.jsonnet merge=ours >>.gitattributes',

                'git merge ${DRONE_COMMIT}',
                'export DEBEMAIL="${DRONE_COMMIT_AUTHOR_EMAIL}" DEBFULLNAME="${DRONE_COMMIT_AUTHOR_NAME}"',
                'gbp dch -S -s "HEAD^" --spawn-editor=never -U low',
                'eatmydata mk-build-deps --install --remove --tool "' + apt_get_quiet + ' -o Debug::pkgProblemResolver=yes --no-install-recommends -y"',
                'export DEB_BUILD_OPTIONS="parallel=$$(nproc)"',
                #'grep -q lib debian/lokinet-bin.install || echo "/usr/lib/lib*.so*" >>debian/lokinet-bin.install',
                'debuild -e CCACHE_DIR -b',
                './contrib/ci/drone-debs-upload.sh ' + distro,
            ]
        }
    ]
};

// Macos build
local mac_builder(name, build_type='Release', werror=true, cmake_extra='', extra_cmds=[], allow_fail=false) = {
    kind: 'pipeline',
    type: 'exec',
    name: name,
    platform: { os: 'darwin', arch: 'amd64' },
    steps: [
        { name: 'submodules', commands: ['git fetch --tags', 'git submodule update --init --recursive'] },
        {
            name: 'build',
            environment: { SSH_KEY: { from_secret: "SSH_KEY" } },
            commands: [
                'echo "Building on ${DRONE_STAGE_MACHINE}"',
                // If you don't do this then the C compiler doesn't have an include path containing
                // basic system headers.  WTF apple:
                'export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"',
                'mkdir build',
                'cd build',
                'cmake .. -G Ninja -DCMAKE_CXX_FLAGS=-fcolor-diagnostics -DCMAKE_BUILD_TYPE='+build_type+' ' +
                    (if werror then '-DWARNINGS_AS_ERRORS=ON ' else '') + cmake_extra,
                'ninja -v',
                './test/testAll --gtest_color=yes',
                './test/catchAll --use-colour yes',
            ] + extra_cmds,
        }
    ]
};


[
    debian_pipeline("Debian buster (armhf)", "arm32v7/debian:buster", arch="arm64", cmake_extra='-DDOWNLOAD_SODIUM=ON'),
]

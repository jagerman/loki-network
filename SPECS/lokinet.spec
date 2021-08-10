Name:           lokinet
Version:        0.9.5
Release:        3%{?dist}
Summary:        Lokinet anonymous, decentralized overlay network

License:        GPLv3+
URL:            https://lokinet.org
Source0:        %{name}-%{version}.src.tar.gz

%global sonamever %{version}

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  pkgconfig
BuildRequires:  libuv-devel
BuildRequires:  oxenmq-devel
BuildRequires:  unbound-devel
BuildRequires:  libsodium-devel
BuildRequires:  systemd-devel
BuildRequires:  libcurl-devel
BuildRequires:  jemalloc-devel
BuildRequires:  libsqlite3x-devel

Patch1: version-as-rpm-version.patch

%description

Lokinet private, decentralized, market-based, Sybil resistant overlay network
for the internet.  Lokinet uses Oxen Service Nodes as relays to provide
censorship resistance and privacy for communication between Lokinet network
clients.

This package contains the lokinet configuration and dependencies needed to
connect to lokinet as a client or SNapp.

%package bin
Summary: Lokinet anonymous, decentralized overlay network -- binaries

%description
This package contains the common binaries for lokinet packages.  Most users will
want to install the lokinet package rather than this one to run lokinet as a
system service.

%package monitor
Summary: lokinetmon monitoring tool for lokinet
Requires: python3
Requires: python3-zmq
Recommends: lokinet

%prep

%autosetup

%build

%ifarch x86_64
%define cmake_arch_args -DCMAKE_CXX_FLAGS="-march=x86-64 -mtune=haswell" -DCMAKE_C_FLAGS="-march=x86-64 -mtune=haswell"
%endif
%ifarch aarch64
%define cmake_arch_args -DNON_PC_TARGET=ON -DCMAKE_CXX_FLAGS="-march=armv8-a+crc -mtune=cortex-a72" -DCMAKE_C_FLAGS="-march=armv8-a+crc -mtune=cortex-a72"
%endif
%ifarch %{arm}
%define cmake_arch_args -DNON_PC_TARGET=ON -DCMAKE_CXX_FLAGS="-marm -march=armv6 -mtune=cortex-a53 -mfloat-abi=hard -mfpu=vfp" -DCMAKE_C_FLAGS="-marm -march=armv6 -mtune=cortex-a53 -mfloat-abi=hard -mfpu=vfp"
%endif

%undefine __cmake_in_source_build
%cmake -DNATIVE_BUILD=OFF -DUSE_AVX2=OFF -DWITH_TESTS=OFF %{cmake_arch_args} -DCMAKE_BUILD_TYPE=Release -DGIT_VERSION="%{release}" -DWITH_SETCAP=OFF
%cmake_build

%install

%cmake_install

cp --preserve=mode contrib/py/admin/lokinetmon %{_bindir}

%files

%license LICENSE.txt
%doc readme.*

%files bin

%{_bindir}/lokinet
%{_bindir}/lokinet-bootstrap
%{_bindir}/lokinet-vpn

%files monitor

%{_bindir}/lokinetmon

%changelog
* Tue Aug 10 2021 Jason Rhinelander <jason@imaginary.ca> - 0.9.5-3
- Updated for rpm.oxen.io packaging
- Split into lokinet/lokinet-bin/lokinet-monitor packages

* Thu Jul 22 2021 Technical Tumbleweed (necro_nemesis@hotmail.com) Lokinet 0.9.5
- Build with systemd-resolved and binary lokinet-bootstrap

* Sun Mar 07 2021 Technical Tumbleweed (necro_nemesis@hotmail.com) Lokinet 0.8.2
- First Lokinet RPM 

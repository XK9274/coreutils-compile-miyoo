unset urls
unset files
unset log_files
unset LDFLAGS
unset CFLAGS

export ROOTDIR="${PWD}"
export BIN_NAME="coreutilsbuild"
export SD_DIR="App"
export FIN_BIN_DIR="/mnt/SDCARD/$SD_DIR/$BIN_NAME"
export CROSS_COMPILE="arm-linux-gnueabihf"
export AR=${CROSS_COMPILE}-ar
export AS=${CROSS_COMPILE}-as
export LD=${CROSS_COMPILE}-ld
export RANLIB=${CROSS_COMPILE}-ranlib
export CC=${CROSS_COMPILE}-gcc
export NM=${CROSS_COMPILE}-nm
export HOST=arm-linux-gnueabihf
export BUILD=x86_64-linux-gnu
export CFLAGS="-s -O3 -fPIC -pthread"
export CXXFLAGS="-s -O3 -fPIC -pthread"
export PATH="$PATH:$FIN_BIN_DIR/bin/"

#Copy these files to lib to stop some test failures on makes, not really needed in most cases - also stops pkgconfig working - could be ldflags
cp /opt/miyoomini-toolchain/arm-linux-gnueabihf/libc/lib/ld-linux-armhf.so.3 /lib/
cp /opt/miyoomini-toolchain/arm-linux-gnueabihf/libc/lib/libpthread.so.0 /lib/
cp /opt/miyoomini-toolchain/arm-linux-gnueabihf/libc/lib/libc.so.6 /lib/
cp /opt/miyoomini-toolchain/arm-linux-gnueabihf/libc/lib/libm.so.6 /lib/
cp /opt/miyoomini-toolchain/arm-linux-gnueabihf/libc/lib/libcrypt.so.1 /lib/
cp /opt/miyoomini-toolchain/arm-linux-gnueabihf/libc/lib/libdl.so.2 /lib/
cp /opt/miyoomini-toolchain/arm-linux-gnueabihf/libc/lib/libutil.so.1 /lib/
cp /opt/miyoomini-toolchain/arm-linux-gnueabihf/libc/lib/libstdc++.so.6 /lib/
cp /opt/miyoomini-toolchain/arm-linux-gnueabihf/libc/lib/libgcc_s.so.1 /lib/

export LOGFILE=./logs/buildtracker.txt # set a full log file
mkdir $ROOTDIR/logs

# Script header section

echo -e "\n \n-Coreutils builder for $CROSS_COMPILE, builds coreutils"

echo -e "-Building \033[32m"$BIN_NAME" and friends\033[0m for: \033[32m"$CROSS_COMPILE "\033[0m"

echo -e "-Building with a prefix of \033[32m$FIN_BIN_DIR\033[0m"	

echo -e "-The build will use \033[32m"$(( $(nproc) - 2 ))"\033[0m cpu threads of the max: \033[32m"`nproc`"\033[0m"
echo  "-The script will output a list of failed makes at the end.."			
echo -e "\n"
echo -e "-Starting shortly - a full logfile with be in: \033[32m"$LOGFILE "\033[0m"
echo -e "\n"

for i in {5..1}; do
    echo -ne "Starting in $i\r"
    sleep 1
done

echo -e "\n\n\n"

while true; do # check if a build has already been completed, it may be best to do a fresh build if you've changed anything
    if [ -d "$ROOTDIR/$BIN_NAME" ]; then
        read -p "A previously completed build of $BIN_NAME already exists. Do you want to remove this & build fresh? (y/n)" rebuildq
        case "$rebuildq" in 
            y|Y ) 
                echo "Deleting previous build..."
                rm -rf $ROOTDIR/$BIN_NAME
                rm -rf $FIN_BIN_DIR
                rm -rf */ 
				rm -f wget-log*
                mkdir $ROOTDIR/logs
                mkdir -p $FIN_BIN_DIR
                break
                ;;
            n|N ) 
                echo "Rebuilding over the top of the last build..."
                break
                ;;
            * ) 
                echo "Invalid input. Please enter 'y' or 'n'."
                ;;
        esac
    else
        echo -e "\033[32mNo previous build detected, starting...\033[0m"
        break
    fi
done

cd ~/workspace/

# Start logging and begin
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1> >(tee -a "$LOGFILE") 2>&1					
# </Envsetup>

#Download everything, but check if it already exists.

urls=(
	# "https://git.savannah.gnu.org/cgit/coreutils.git/snapshot/coreutils-9.3.tar.gz"
	"https://ftp.gnu.org/gnu/m4/m4-latest.tar.xz"
	"https://pkgconfig.freedesktop.org/releases/pkg-config-0.29.2.tar.gz"	
	"https://ftp.gnu.org/gnu/autoconf/autoconf-latest.tar.gz"
	"https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.xz"
	"https://ftp.gnu.org/pub/gnu/gettext/gettext-0.21.1.tar.gz"
	"https://ftp.gnu.org/gnu/gperf/gperf-3.1.tar.gz"
	"https://ftp.gnu.org/gnu/texinfo/texinfo-7.0.3.tar.xz"
	"https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz"
	"https://ftp.gnu.org/gnu/glibc/glibc-2.37.tar.xz"
	"https://ftp.gnu.org/gnu/gawk/gawk-5.2.1.tar.xz"
)

# Parallel download and wait until finished.
pids=()
for url in "${urls[@]}"; do
  file_name=$(basename "$url")
  if [ ! -f "$file_name" ]; then
    echo "Downloading $file_name..."
    wget -q "$url" &
    pids+=($!)
  else
    echo "$file_name already exists, skipping download..."
  fi
done

for pid in "${pids[@]}"; do
  wait $pid
done

echo -e "\n\n\033[32mAll downloads finished, now building..\033[0m\n\n"

# Check all files have downloaded before trying to build

files=(
    "coreutils-9.3.tar.gz"
	"m4-latest.tar.xz"
	"pkg-config-0.29.2.tar.gz"
	"autoconf-latest.tar.gz"
	"automake-1.16.5.tar.xz"
	"gettext-0.21.1.tar.gz"
	"bison-3.8.2.tar.xz"
	"gperf-3.1.tar.gz"
	"glibc-2.37.tar.xz"
	"gawk-5.2.1.tar.xz"
)

missing_files=()
for file in "${files[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -eq 0 ]; then
    echo -e "\033[32mAll files exist...\033[0m\n\n"
    sleep 1
else #check if any of the downloads failed, if they did try to redownload, if they still fail prompt for a new url with the filename..
    echo "Missing files: ${missing_files[@]}"
    echo "Trying to download again...."
    for file in "${missing_files[@]}"; do
        for url in "${urls[@]}"; do
            if [[ "$url" == *"$file"* ]]; then
                wget -q "$url"
                if [ $? -ne 0 ]; then
                    echo "Error downloading $file from $url"
                    read -p "Enter a new WORKING URL for $file: " new_url
                    wget -q "$new_url"
                fi
            fi
        done
    done
fi

## pkg config 
echo -e "-Compiling \033[32mpkconfig\033[0m"
tar -xf pkg-config-0.29.2.tar.gz &
wait $!
cd pkg-config-0.29.2
./configure CC=$CC AR=$AR RANLIB=$RANLIB LD=$LD --host=$HOST --build=$BUILD --target=$TARGET --prefix=$FIN_BIN_DIR --disable-shared --with-internal-glib glib_cv_stack_grows=no glib_cv_stack_grows=no glib_cv_uscore=no ac_cv_func_posix_getpwuid_r=yes ac_cv_func_posix_getgrgid_r=yes &
wait $!
make -j$(( $(nproc) - 2 )) && make install -j$(( $(nproc) - 2 )) > ../logs/pkgconfigbuildlog.txt 2>&1  &
wait $!
export PKG_CONFIG_PATH="$FIN_BIN_DIR/lib/pkgconfig"
export PKG_CONFIG="$FIN_BIN_DIR/bin/pkg-config"
cd ..

# m4 (required by autoconf for the M4 var)
echo -e "-Compiling \033[32mm4\033[0m"
tar -xf m4-latest.tar.xz &
wait $!
cd m4-1.4.19
./configure CC=$CC --host=$HOST --build=$BUILD --prefix=$FIN_BIN_DIR --enable-shared &
wait $!
make -j$(( $(nproc) - 2 )) && make install -j$(( $(nproc) - 2 )) > ../logs/m4buildlog.txt 2>&1 &
wait $!
cd ..

# Autoconf
echo -e "-Compiling \033[32mautoconf\033[0m"
tar -xf autoconf-latest.tar.gz &
wait $!
cd autoconf-2.71/
./configure CC=$CC --host=$HOST --build=$BUILD --prefix=$FIN_BIN_DIR M4=$FIN_BIN_DIR/bin/m4 &
wait $!
make clean && make -j$(( $(nproc) - 2 )) && make install -j$(( $(nproc) - 2 )) > ../logs/autoconf-2.71.txt 2>&1 &
cd ..

# Crosscompile Gettext package 
echo -e "-Compiling \033[32mgettext\033[0m"
tar -xf gettext-0.21.1.tar.gz &
wait $!
cd gettext-0.21.1
./configure CC=$CC --host=$HOST --build=$BUILD  --prefix=$FIN_BIN_DIR --disable-shared --disable-mtab &
wait $!
make clean && make -j$(( $(nproc) - 2 )) && make install -j$(( $(nproc) - 2 )) > ../logs/gettext-0.21.1.txt 2>&1 &
wait $!
cd ..

# texinfo (required by gnutls for MAKEINFO)
echo -e "-Compiling \033[32mtexinfo\033[0m"
tar -xf texinfo-7.0.3.tar.xz &
wait $!
cd texinfo-7.0.3
./configure CC=$CC --host=$HOST --build=$BUILD --prefix=$FIN_BIN_DIR --enable-shared &
wait $!
make clean && make -j$(( $(nproc) - 2 )) && make install -j$(( $(nproc) - 2 )) > ../logs/texibuildlog.txt 2>&1 &
wait $!
cd ..

# bison
echo -e "-Compiling \033[32mbison\033[0m"
tar -xf bison-3.8.2.tar.xz &
wait $!
cd bison-3.8.2
./configure CC=$CC --host=$HOST --build=$BUILD --prefix=$FIN_BIN_DIR  &
wait $!
make clean && make -j$(( $(nproc) - 2 )) && make install -j$(( $(nproc) - 2 )) > ../logs/bisonbuildlog.txt 2>&1 &
wait $!
cd ..

# gperf
echo -e "-Compiling \033[32mgperf\033[0m"
tar -xf gperf-3.1.tar.gz &
wait $!
cd gperf-3.1
./configure CC=$CC --host=$HOST --build=$BUILD --prefix=$FIN_BIN_DIR --enable-shared &
wait $!
make clean && make -j$(( $(nproc) - 2 )) && make install -j$(( $(nproc) - 2 )) > ../logs/gperfbuildlog.txt 2>&1 &
wait $!
cd ..

# Automake
echo -e "-Compiling \033[32mautomake\033[0m"
tar -xf automake-1.16.5.tar.xz &
wait $!
cd automake-1.16.5
./configure CC=$CC --host=$HOST --build=$BUILD --prefix=$FIN_BIN_DIR AUTOCONF=$FIN_BIN_DIR/bin/autoconf &
wait $!
make clean && make -j$(( $(nproc) - 2 )) && make install -j$(( $(nproc) - 2 )) > ../logs/automake-1.16.5.txt 2>&1 &
wait $!
cd ..

# gawk
echo -e "-Compiling \033[32mgperf\033[0m"
tar -xf gawk-5.2.1.tar.xz &
wait $!
cd gawk-5.2.1
./configure CC=$CC --host=$HOST --build=$BUILD --prefix=$FIN_BIN_DIR --enable-shared &
wait $!
make clean && make -j$(( $(nproc) - 2 )) && make install -j$(( $(nproc) - 2 )) > ../logs/gperfbuildlog.txt 2>&1 &
wait $!
cd ..

# glib
echo -e "-Compiling \033[32mglibc\033[0m"
tar -xf glibc-2.37.tar.xz &
wait $!
cd glibc-2.37
mkdir build
cd build
../configure CC=$CC --host=$HOST --build=$BUILD --prefix=$FIN_BIN_DIR --enable-shared &
wait $!
make clean && make -j$(( $(nproc) - 2 )) && make install -j$(( $(nproc) - 2 )) > ../../logs/glibcbuildlog.txt 2>&1 &
wait $!
cd ..
cd ..

# coreutils
git clone git://git.sv.gnu.org/coreutils
echo -e "-Compiling \033[32mcoreutils\033[0m"
wait $!
cd coreutils
sed -i 's/ \(gl_WARN_ADD([[]-Werror[]], \)/#\1/' configure.ac # this build adds Werror by default which fails on some malloc stuff, remove it
./bootstrap
export FORCE_UNSAFE_CONFIGURE=1 #angry error about root running a configure
sed -i '8482,8686d' configure # more elite hacks (removes the checks for the year2038 issue and large files support..(which was an accident))
./configure --host=$HOST --prefix=$FIN_BIN_DIR &
wait $!
make install-exec && make install -j$(( $(nproc) - 2 )) > ../logs/coreutilbuildlog.txt 2>&1 &
wait $!
cd ~/workspace


if [ -f "/mnt/SDCARD/App/coreutilsbuild/bin/numfmt" ]; then # Check if the bin file for one of the coreutils exists. $FIN_BIN_DIR changes to $ROOTDIR here as it gets copied to the workspace.
	echo -e "\n\n"
	echo "Preparing export folder"
	echo -e "\n\n"
	echo "Moving built files to workspace area"
	mkdir -v $ROOTDIR/$BIN_NAME
	cp -r "$FIN_BIN_DIR/"* "$ROOTDIR/$BIN_NAME" &
	wait $!
	
	# Fix some libraries
	# rm  $ROOTDIR/$BIN_NAME/lib/libnl-3.so.200
	# cp  $ROOTDIR/$BIN_NAME/lib/libnl-3.so.200.20.0 $ROOTDIR/$BIN_NAME/lib/libnl-3.so.200
	# rm  $ROOTDIR/$BIN_NAME/lib/libnl-genl-3.so.200
	# cp  $ROOTDIR/$BIN_NAME/lib/libnl-genl-3.so.200.20.0 $ROOTDIR/$BIN_NAME/lib/libnl-genl-3.so.200
	
	# cp $ROOTDIR/$BIN_NAME/sbin/dnsmasq $ROOTDIR/$BIN_NAME/bin
	# cp $ROOTDIR/iw-5.9/iw $ROOTDIR/$BIN_NAME/bin
	
fi	

log_files=(				   					   
	"pkgconfigbuildlog.txt"
	"m4buildlog.txt"
	"autoconf-2.71.txt"
	"automake-1.16.5.txt"
	"bisonbuildlog.txt"
	"gettext-0.21.1.txt"
	"texibuildlog.txt"
	"gperfbuildlog.txt"
	"coreutilbuildlog.txt"
	"glibcbuildlog.txt"
)

for log_file in "${log_files[@]}"
do
  if [ ! -f "logs/$log_file" ]; then
    echo "$log_file FAILED"
	failed_logs="$failed_logs $log_file"
	else
	echo "$log_file built OK"
  fi
done

# checks if the final product dir was moved to the /workspace/ folder, indicating it built OK
if [ -z "$failed_logs" ]; then
  if [ -d "$ROOTDIR/$BIN_NAME" ]; then
	echo -e "\033[32mComplete - your finished build is in /workspace/$BIN_NAME, this will contain all build products...\033[0m "
  else
	echo -e "Build failed, check ~/workspace/logs/buildtracker.txt for more info"
  fi
else
  if [ -d "$ROOTDIR/$BIN_NAME" ]; then
	echo -e "\033[32mComplete - your finished build is in /workspace/$BIN_NAME, this will contain all build products... "
	echo -e "These packages did not complete\033[31m$failed_logs\033[32m but it has not affected the $BIN_NAME bin being built\033[0m."
  else
	echo -e "Build failed, these packages did not complete \033[31m$failed_logs\033[0m check ~/workspace/logs/buildtracker.txt for more info"
  fi
fi	
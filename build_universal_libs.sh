#!/bin/bash

ROOT=${PWD}
SOURCE_DIR=${PWD}/../../
INSTALL_DIR=${ROOT}/products
DEVICE=iphoneos
SIMULATOR=iphonesimulator
#COMPILER=com.apple.compilers.llvmgcc42
COMPILER=com.apple.compilers.llvm.clang.1_0
UNIVERSAL_DIR=${INSTALL_DIR}/universal

DEVICE_DIR=${ROOT}/build/device
SIMULATOR_DIR=${ROOT}/build/simulator

TARGETS="install"

CMAKE_OPTIONS="-D BUILD_OSG_APPLICATIONS:BOOL=OFF \
	-D OSG_WINDOWING_SYSTEM:STRING=IOS \
	-D OPENGL_PROFILE:STRING=GLES1 \
	-D IPHONE_SDKVER:STRING="7.1" \
  -D IPHONE_VERSION_MIN:STRING="7.0" \
	-D OSG_USE_FLOAT_MATRIX:BOOL=ON \
	-D CURL_INCLUDE_DIR:PATH="" \
  -D JPEG_INCLUDE_DIR:PATH="" \
  -D JPEG_LIBRARY="" \
	-D DYNAMIC_OPENSCENEGRAPH:BOOL=OFF \
	-D DYNAMIC_OPENTHREADS:BOOL=OFF \
  -D OSG_CXX_LANGUAGE_STANDARD:STRING=C++98 \
  -D OSG_USE_LOCAL_LUA_SOURCE:BOOL=ON \
	-U CMAKE_CXX_FLAGS "

CMAKE_DEVICE_OPTIONS="-DCMAKE_OSX_ARCHITECTURES:STRING='armv7;armv7s'"
CMAKE_SIMULATOR_OPTIONS=""

# libfreetype
CMAKE_DEVICE_OPTIONS="${CMAKE_DEVICE_OPTIONS} \
  -D FREETYPE_INCLUDE_DIR_freetype2:PATH=${ROOT}/3rdParty/freetype/include \
  -D FREETYPE_INCLUDE_DIR_ft2build:PATH=${ROOT}/3rdParty/freetype/include \
  -D FREETYPE_LIBRARY:PATH=${ROOT}/3rdParty/freetype/lib/freetype.a"

CMAKE_SIMULATOR_OPTIONS="${CMAKE_SIMULATOR_OPTIONS} \
  -D FREETYPE_INCLUDE_DIR_freetype2:PATH=${ROOT}/3rdParty/freetype/include \
  -D FREETYPE_INCLUDE_DIR_ft2build:PATH=${ROOT}/3rdParty/freetype/include \
  -D FREETYPE_LIBRARY:PATH=${ROOT}/3rdParty/freetype/lib/freetype.a"

# libcurl
CMAKE_DEVICE_OPTIONS="${CMAKE_DEVICE_OPTIONS} \
  -D CURL_INCLUDE_DIR:PATH=${ROOT}/3rdParty/libcurl \
  -D CURL_LIBRARY:PATH=${ROOT}/3rdParty/libcurl/lib/device/libcurl.a"

CMAKE_SIMULATOR_OPTIONS="${CMAKE_SIMULATOR_OPTIONS} \
  -D CURL_INCLUDE_DIR=${ROOT}/3rdParty/libcurl \
  -D CURL_LIBRARY=${ROOT}/3rdParty/libcurl/lib/simulator/libcurl.a"

IGNORE_CMAKE_STEP=0
DO_CLEAN_STEP=0
OUTPUT_FILTER="/usr/bin/grep -v setenv"
XCODEBUILD=/Developer/usr/bin/xcodebuild
if [ ! -f ${XCODEBUILD} ]; then
  XCODEBUILD=/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild
fi


# handle arguments

USAGE=$(
cat <<EOF
$0 [OPTION]
-i           ignore cmake-config step
-o VALUE     set the output-directory for libs + header
-t TARGET(s) target, separate targets with ;
-c           clean all targets
EOF
)

while getopts "cio:t:" OPTION; do
  case "$OPTION" in
    i)
      IGNORE_CMAKE_STEP=1
      ;;
    c)
      DO_CLEAN_STEP=1
      ;;
    o)
      #the colon after b in the args string above signifies that
      #  b should be accompanied with a user-defined value.
      #that value will be stored in the OPTARG environment variable
      UNIVERSAL_DIR="$OPTARG"
      ;;
    t)
      TARGETS="$OPTARG"
      ;;
    *)
      echo "unrecognized option ${OPTARG}"
      echo "$USAGE"
      exit 1
      ;;
  esac
done

echo "install dir      : ${UNIVERSAL_DIR}"
echo "ignore cmake-step: ${IGNORE_CMAKE_STEP}"
echo "clean targets    : ${DO_CLEAN_STEP}"
echo "targets          : ${TARGETS}"

#create build dirs

mkdir -p ${SIMULATOR_DIR}
mkdir -p ${DEVICE_DIR}

mkdir -p ${UNIVERSAL_DIR}/lib

mkdir -p ${INSTALL_DIR}/device
mkdir -p ${INSTALL_DIR}/simulator


create_project () {
	cd ${ROOT}/build/${1}
	echo "/usr/bin/cmake -G Xcode \
    ${CMAKE_OPTIONS} \
    ${3} \
    -D ${2}:BOOL=ON \
    -D CMAKE_INSTALL_PREFIX:PATH="${INSTALL_DIR}/${1}" \
    ${SOURCE_DIR}"

	/usr/bin/cmake -G Xcode \
		${CMAKE_OPTIONS} \
		${3} \
		-D ${2}:BOOL=ON \
		-D CMAKE_INSTALL_PREFIX:PATH="${INSTALL_DIR}/${1}" \
		${SOURCE_DIR}

}


build_project () {
  TARGET=${1}
  DEVICE=${2}
  ACTION=${3}

  echo "Building ${TARGET} FOR ${DEVICE}..."

  ${XCODEBUILD} -configuration Debug -target "${TARGET}" -sdk ${DEVICE} ${ACTION} -parallelizeTargets RUN_CLANG_STATIC_ANALYZER=NO GCC_VERSION=${COMPILER} | grep -A 5 error
  #if [ $? -eq 1 ] ; then
  #  echo "compile went wrong"
  #  exit 1
  #fi

  ${XCODEBUILD} -configuration Release -target "${TARGET}" -sdk ${DEVICE} ${ACTION} -parallelizeTargets RUN_CLANG_STATIC_ANALYZER=NO GCC_VERSION=${COMPILER} | grep -A 5 error
  #if [ $? -eq 1 ] ; then
  #  echo "compile went wrong"
  #  exit 1
  #fi

}

create_universal_lib () {
   FILE_NAME=${1}
   echo "creating universal lib '${FILE_NAME}'"

   lipo -create -output "${UNIVERSAL_DIR}/lib/${FILE_NAME}" "${DEVICE_DIR}/lib/${FILE_NAME}" "${SIMULATOR_DIR}/lib/${FILE_NAME}"
}


if [ ${IGNORE_CMAKE_STEP} -eq 0 ]; then
# create xcode-projects
  create_project device OSG_BUILD_PLATFORM_IPHONE "${CMAKE_DEVICE_OPTIONS}"
  create_project simulator OSG_BUILD_PLATFORM_IPHONE_SIMULATOR "${CMAKE_SIMULATOR_OPTIONS}"
fi

# build device
cd ${ROOT}/build/device
for i in $(echo $TARGETS | tr ";" "\n")
do
  if [ ${DO_CLEAN_STEP} -eq 1 ]; then
    build_project $i ${DEVICE} clean
  fi
  build_project $i ${DEVICE} build
done


# build simulator
cd ${ROOT}/build/simulator
for i in $(echo $TARGETS | tr ";" "\n")
do
  if [ ${DO_CLEAN_STEP} -eq 1 ]; then
    build_project $i ${SIMULATOR} clean
  fi
  build_project $i ${SIMULATOR} build
done


# create univeral libs
for i in $( ls "${DEVICE_DIR}/lib" );
do
   if [ -d $i ]
      then
            echo "ignoring directory ${i}"
      else
      		if [ ${i: -2} == ".a" ]
      		then
		      	create_universal_lib $i
			fi
    fi
done

# copy header files
cp -r ${SOURCE_DIR}/include ${UNIVERSAL_DIR}
cp -r ${ROOT}/build/device/include/osg/* ${UNIVERSAL_DIR}/include/osg/
cp -r ${ROOT}/build/device/include/OpenThreads/* ${UNIVERSAL_DIR}/include/OpenThreads/

rm -rf ${INSTALL_DIR}/device
rm -rf ${INSTALL_DIR}/simulator

# Minimal bindings to be able to extract metadata and thumbnail with libvips
{.passL: gorge("pkg-config --libs vips").}
{.passc: gorge("pkg-config --cflags vips").}
{.push header: "<vips/vips.h>".}

const VIPS_INTERESTING_ENTROPY* = 2

type VipsDemandStyle* = enum 
  VIPS_DEMAND_STYLE_ERROR = -1,  
  VIPS_DEMAND_STYLE_SMALLTILE,  
  VIPS_DEMAND_STYLE_FATSTRIP,
  VIPS_DEMAND_STYLE_THINSTRIP,
  VIPS_DEMAND_STYLE_ANY      

type VipsImageType* = enum 
  VIPS_IMAGE_ERROR = -1,  
  VIPS_IMAGE_NONE,
  VIPS_IMAGE_SETBUF,
  VIPS_IMAGE_SETBUF_FOREIGN,
  VIPS_IMAGE_OPENIN,
  VIPS_IMAGE_MMAPIN,
  VIPS_IMAGE_MMAPINRW,
  VIPS_IMAGE_OPENOUT,
  VIPS_IMAGE_PARTIAL

type VipsInterpretation* = enum
  VIPS_INTERPRETATION_ERROR = -1,
  VIPS_INTERPRETATION_MULTIBAND = 0,
  VIPS_INTERPRETATION_B_W = 1,
  VIPS_INTERPRETATION_HISTOGRAM = 10,
  VIPS_INTERPRETATION_XYZ = 12,
  VIPS_INTERPRETATION_LAB = 13,
  VIPS_INTERPRETATION_CMYK = 15,
  VIPS_INTERPRETATION_LABQ = 16,
  VIPS_INTERPRETATION_RGB = 17,
  VIPS_INTERPRETATION_CMC = 18,
  VIPS_INTERPRETATION_LCH = 19,
  VIPS_INTERPRETATION_LABS = 21,
  VIPS_INTERPRETATION_sRGB = 22,
  VIPS_INTERPRETATION_YXY = 23,
  VIPS_INTERPRETATION_FOURIER = 24,
  VIPS_INTERPRETATION_RGB16 = 25,
  VIPS_INTERPRETATION_GREY16 = 26,
  VIPS_INTERPRETATION_MATRIX = 27,
  VIPS_INTERPRETATION_scRGB = 28,
  VIPS_INTERPRETATION_HSV = 29,
  VIPS_INTERPRETATION_LAST = 30

type VipsBandFormat* = enum
  VIPS_FORMAT_NOTSET = -1,
  VIPS_FORMAT_UCHAR = 0,
  VIPS_FORMAT_CHAR = 1,
  VIPS_FORMAT_USHORT = 2,
  VIPS_FORMAT_SHORT = 3,
  VIPS_FORMAT_UINT = 4,
  VIPS_FORMAT_INT = 5,
  VIPS_FORMAT_FLOAT = 6,
  VIPS_FORMAT_COMPLEX = 7,
  VIPS_FORMAT_DOUBLE = 8,
  VIPS_FORMAT_DPCOMPLEX = 9,
  VIPS_FORMAT_LAST = 10

type VipsCoding* = enum
  VIPS_CODING_ERROR = -1,
  VIPS_CODING_NONE = 0,
  VIPS_CODING_LABQ = 2,
  VIPS_CODING_RAD = 6,
  VIPS_CODING_LAST = 7

type VipsAccess* = enum
  VIPS_ACCESS_RANDOM,
  VIPS_ACCESS_SEQUENTIAL,
  VIPS_ACCESS_SEQUENTIAL_UNBUFFERED,
  VIPS_ACCESS_LAST

type
  VipsImage* {.importc: "VipsImage*".} = pointer

proc vips_thumbnail*(filename: cstring, output: ptr VipsImage, width: cint) {.importc, varargs.}
proc vips_image_write_to_file*(img: VipsImage, filename: cstring) {.importc, varargs.}
proc vips_image_write_to_memory*(img: VipsImage, size: ptr csize_t): pointer {.importc.}
proc vips_jpegsave_buffer* (img: VipsImage, buffer: ptr cstring, size: ptr csize_t) {.importc, varargs.}
proc vips_image_new_from_file*(filename: cstring): VipsImage {.importc, varargs.}
proc vips_image_get_width*(img: VipsImage): cint {.importc.}
proc vips_image_get_height*(img: VipsImage): cint {.importc.}
proc vips_image_hasalpha(image: VipsImage): cint {.importc.}
proc vips_image_get_interpretation*(img: VipsImage): VipsInterpretation {.importc.}
proc vips_image_get_fields*(img: VipsImage): cstringArray {.importc.}
proc vips_image_get_as_string*(img: VipsImage, name: cstring, output: ptr cstring): int {.importc.}
proc vips_image_get_string*(img: VipsImage, name: cstring, output: ptr cstring): int {.importc.}
proc vips_colourspace*(input: VipsImage, output: ptr VipsImage, space: VipsInterpretation): cint {.importc, varargs.}
proc vips_colourspace_issupported*(input: VipsImage): cint {.importc.}
proc vips_addalpha*(input: VipsImage, output: ptr VipsImage): cint {.importc, varargs.}
proc vips_flatten*(input: VipsImage, output: ptr VipsImage): cint {.importc, varargs.}
proc g_free*(mem: pointer) {.importc.}
proc g_object_unref*(mem: pointer) {.importc.}
proc g_strfreev*(mem: pointer) {.importc.}
proc VIPS_INIT(argv0: cstring) {.importc.}

{.pop.}

#proc printf(fmt: cstring): cint {.importc, varargs.}

proc makeThumbnail*(filename: string, size: int): string =
  var img: VipsImage
  vips_thumbnail(filename.cstring, addr img, size.cint, "crop", VIPS_INTERESTING_ENTROPY, nil)
  if img.isNil:
    return
  var 
    size: csize_t
    buffer: cstring
  vips_jpegsave_buffer(img, addr buffer, addr size, nil)
  result = newString(size)
  copyMem(addr result[0], buffer, size)
  g_object_unref( img )
  g_free(buffer)
  
proc makeThumbnailImage*(filename: string, size: int): VipsImage =
  vips_thumbnail(filename.cstring, addr result, size.cint, "crop", VIPS_INTERESTING_ENTROPY, nil)

proc saveJpeg*(image: VipsImage): string =
  var 
    size: csize_t
    buffer: cstring
  vips_jpegsave_buffer(image, addr buffer, addr size, nil)
  result = newString(size)
  copyMem(addr result[0], buffer, size)
  g_free(buffer)

proc timestamp*(image: VipsImage): string =
  var value: cstring
  for name in ["exif-ifd2-DateTimeOriginal", "exif-ifd2-DateTimeDigitized", "exif-ifd0-DateTime"]:
    if vips_image_get_string(image, "exif-ifd2-DateTimeOriginal".cstring, addr value) == 0:
      return ($value).substr(0, 18)

proc readMeta*(filename: string): tuple[width, height: int, date: string] =
  var img: VipsImage = vips_image_new_from_file(filename.cstring, nil)
  if not img.isNil:
    result.width = vips_image_get_width(img)
    result.height = vips_image_get_height(img)
    result.date = timestamp(img)
    g_object_unref(img)

proc readSize*(filename: string): tuple[width, height: int] =
  var img: VipsImage = vips_image_new_from_file(filename.cstring, nil)
  if not img.isNil:
    result.width = vips_image_get_width(img)
    result.height = vips_image_get_height(img)
    g_object_unref(img)

type Color* = object
  r*, g*, b*: uint8

proc getRGB*(image: VipsImage): seq[Color] =
  var
    converted: VipsImage = nil
    no_alpha: VipsImage = nil
    buffer: pointer
    size: csize_t

  if vips_image_hasalpha(image).bool: 
    discard vips_flatten(image, addr no_alpha, nil)
    defer: g_object_unref(no_alpha)
  else:
    no_alpha = image
  if vips_image_get_interpretation(no_alpha) != VIPS_INTERPRETATION_RGB and vips_image_get_interpretation(no_alpha) != VIPS_INTERPRETATION_sRGB:
    #echo $vips_image_get_interpretation(no_alpha)
    #echo no_alpha.vips_colourspace_issupported().bool
    if vips_colourspace(no_alpha, addr converted, VIPS_INTERPRETATION_RGB, nil) != 0:
      echo "WARNING: failed to convert colors in getRGB"
      return
    #echo converted.isNil
    defer: g_object_unref(converted)
  else:
    converted = no_alpha
  buffer = vips_image_write_to_memory(converted, addr size)

  result = newSeq[Color](size div 3)
  copyMem(addr result[0], buffer, size)
  g_free(buffer)

proc width*(image: VipsImage): int = vips_image_get_width(image).int
proc height*(image: VipsImage): int = vips_image_get_height(image).int
proc close*(image: VipsImage) =
  if not image.isNil:
    g_object_unref(image)

VIPS_INIT("")

when isMainModule:
  import os
  #var img: VipsImage
  #vips_thumbnail(paramStr(1).cstring, addr img, 256, "crop", VIPS_INTERESTING_ENTROPY, nil)
  #vips_image_write_to_file(img, paramStr(2).cstring)
  
  #let img = makeThumbnail(paramStr(1), 244)
  #writeFile("foo.jpeg", img)
  #echo findSize(paramStr(1))
  
  var image = vips_image_new_from_file(paramStr(1), nil)
  let rgb = getRGB(image)
  echo (image.width, image.height, rgb.len)
  image.close()
  
  #var image = vips_image_new_from_file(paramStr(1), nil)
  #echo image.timestamp()
  #image.close()


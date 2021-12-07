import vips

# basic image hash implementation
# 1) compute average grayscale picture downsized to 8x8
# 2) binarize as sign of difference between neighboring pixels
# 3) hash is vertical xor horizontal
# TODO: xor is not a good operator
proc dhash(rgb: seq[Color], width, height: int): uint64 =
  var 
    accumulator = newSeq[uint64](8 * 8)
  let box_h = height div 8
  let box_w = width div 8
  for y in 0 ..< 8:
    for x in 0 ..< 8:
      let cell = x + y * 8
      accumulator[cell] = 0
      var count = 0'u64
      for j in y * box_h ..< (y + 1) * box_h:
        for i in x * box_w ..< (x + 1) * box_w:
          if i < width and j < height:
            let color = rgb[i + j * width]
            accumulator[cell] += color.r.uint64 + color.g.uint64 + color.b.uint64
            count += 3
      accumulator[cell] = accumulator[cell] div count

  for y in 0 ..< 8:
    for x in 0 ..< 8:
      let 
        cell = x + y * 8
        h_bit = if accumulator[cell] > accumulator[(cell + 1) mod 8]: 1 else: 0
        v_bit = if accumulator[cell] > accumulator[(cell + 8) mod 64]: 1 else: 0
        bit = h_bit xor v_bit
      result = result or (bit.uint64 shl (x + y * 8))

# result is 0 if pixels could not be retrieved
proc dhash*(image: VipsImage): uint64 =
  let 
    rgb = getRGB(image)
  if rgb.len == image.width * image.height:
    result = dhash(rgb, image.width, image.height)

when isMainModule: 
  import os
  import strutils
  for i in 1 .. paramCount():
    #var image = vips_image_new_from_file(paramStr(i), nil)
    var image = makeThumbnailImage(paramStr(i), 224)
    let hash = dhash(image)
    echo hash.toHex(), ' ', paramStr(i)
    image.close()

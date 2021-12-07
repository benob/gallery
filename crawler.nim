import strutils
import base64
import os
import re
import times
import std/pathnorm
import std/asyncdispatch

import vips
import picture_db
import dhash

proc parseExifDate(text: string): string =
  #YYYY-MM-DD HH:MM:SS
  let tokens = text.split(' ')
  if tokens.len != 2: return ""
  return tokens[0].replace(':', '-') & " " & tokens[1]

proc guessDate(filename: string): string =
  var matches: array[8, string]
  if find(filename, re"(^|[^\d])(\d\d\d\d)-(\d\d)-(\d\d) (\d\d)\.(\d\d)\.(\d\d)([^\d]|$)", matches) != -1 or find(filename, re"(^|[^\d])(\d\d\d\d)(\d\d)(\d\d)[^\d](\d\d)(\d\d)(\d\d)([^\d]|$)", matches) != -1:
    return matches[1] & '-' & matches[2] & '-' & matches[3] & " " & matches[4] & ":" & matches[5] & ":" & matches[6]
  elif find(filename, re"(^|[^\d])(\d\d\d\d)-(\d\d)-(\d\d)([^\d]|$)", matches) != -1 or find(filename, re"(^|[^\d])(\d\d\d\d)/(\d\d)/(\d\d)([^\d]|$)", matches) != -1 or find(filename, re"(^|[^\d])(\d\d\d\d)(\d\d)(\d\d)([^\d]|$)", matches) != -1:
    return matches[1] & '-' & matches[2] & '-' & matches[3] & " 00:00:00"
  else:
    return getLastModificationTime(filename).format("yyyy-MM-dd HH:mm:ss")

#TODO: orientation
proc extractMetadata*(pics: var PictureDB, base, filename: string): bool =
  if not (filename.toLowerAscii().endswith(".jpg") or filename.toLowerAscii().endswith(".jpeg")):
    return false
  if pics.hasPath(filename):
    echo "already indexed ", filename
    return false
  var
    date = ""
    width = 0
    height = 0

  (width, height, date) = readMeta(base / filename)
  date = parseExifDate(date)

  if date == "":
    date = guessDate(base / filename)

  let thumbnailImage = makeThumbnailImage(base / filename, 244)
  if not thumbnailImage.isNil:
    let 
      hash = dhash(thumbnailImage).toHex()
      duplicate = pics.hasHash(hash)
      thumbnail = saveJpeg(thumbnailImage)
    pics.add(hash, filename, width, height, date, base64.encode(thumbnail), duplicate)
    echo hash, ' ', width, ' ', height, ' ', date, ' ', base / filename
    thumbnailImage.close()
  else:
    echo "failed to make thumbnail ", filename 
  return true

proc extractMetadata*(pics: var PictureDB, base: string) =
  for filename in walkDirRec(base, followFilter = {pcDir, pcLinkToDir}):
    discard pics.extractMetadata(base, filename[(base.len + 1) .. ^1])
  echo "done"

type
  Crawler = ref object
    pics: PictureDB
    base: string
    queue: seq[string]

proc newCrawler*(pics: PictureDB, base: string): Crawler =
  Crawler(pics: pics, base: normalizePath(base), queue: @[])

proc start*(crawler: Crawler) =
  crawler.queue = @[]
  for filename in walkDirRec(crawler.base, followFilter = {pcDir, pcLinkToDir}):
    crawler.queue.add(filename[(crawler.base.len + 1) .. ^1])

  proc step(fd: AsyncFD): bool {.gcsafe.} =
    if crawler.queue.len > 0:
      let filename = crawler.queue.pop()
      discard crawler.pics.extractMetadata(crawler.base, filename)
    else:
      return true

  proc refresh(fs: AsyncFD): bool {.gcsafe.} =
    echo "refresh START"
    addTimer(1, false, step)
    echo "refresh DONE"

  addTimer(1000 * 3600, false, refresh)

when isMainModule:
  if paramCount() != 1:
    echo "usage: " &  getAppFilename() & " <directory>"
    quit(1)

  let dir = paramStr(1)

  var pics = newPictureDB(dir / "db.sqlite")
  echo pics.len
  pics.extractMetadata(dir)
  echo pics.len

  #for pic in pics.list():
  #  echo (pic.width, pic.height, pic.date)
  


import db_sqlite
import strutils
import sequtils

type PictureDB* = DbConn

proc newPictureDB*(dbname: string): PictureDB =
  echo "DB: " & dbname
  let db = open(dbname, "", "", "")
  db.exec(sql"""CREATE TABLE IF NOT EXISTS pictures (id INTEGER PRIMARY KEY AUTOINCREMENT, hash TEXT, path TEXT, width INT, height INT, date DATE, thumbnail TEXT, duplicate BOOLEAN)""")
  db.exec(sql"""CREATE INDEX IF NOT EXISTS index_picture_date ON pictures (date)""")
  db.exec(sql"""CREATE INDEX IF NOT EXISTS index_picture_date ON pictures (date, duplicate)""")
  db.exec(sql"""CREATE INDEX IF NOT EXISTS index_picture_path ON pictures (path)""")
  db.exec(sql"""CREATE INDEX IF NOT EXISTS index_picture_dhash ON pictures (hash)""")
  #db.exec(sql"""CREATE INDEX IF NOT EXISTS index_picture_duplicate ON pictures (duplicate)""")
  result = db

#proc closePictures*(pics: var PictureDB):
#  db_sqlite.close(pics)

type Picture* = object
  id*: int
  path*: string
  hash*: string
  width*: int
  height*: int
  date*: string
  thumbnail*: string
  duplicate*: bool

iterator list*(pics: PictureDB, first = 0, num = 100): Picture =
  for found in pics.fastRows(sql"SELECT * FROM pictures ORDER BY date DESC LIMIT ?, ?", first, num):
    var pic: Picture
    pic.id = found[0].parseInt
    pic.hash = found[1]
    pic.path = found[2]
    pic.width = parseInt(found[3])
    pic.height = parseInt(found[4])
    pic.date = found[5]
    pic.thumbnail = found[6]
    pic.duplicate = if found[7] == "true": true else: false
    yield pic

proc listIds*(pics: PictureDB): seq[int] =
  for found in pics.fastRows(sql"SELECT id FROM pictures ORDER BY date DESC"):
    result.add(found[0].parseInt)

proc len*(pics: PictureDB): int =
  for found in pics.fastRows(sql"SELECT count(*) FROM pictures"):
    return found[0].parseInt

#proc updateByDate(pics: PictureDB) =
#  pics.exec(sql"DROP TABLE IF EXISTS bydate")
#  pics.exec(sql"CREATE TABLE bydate AS SELECT id FROM pictures WHERE duplicate IS false ORDER BY date DESC")

proc add*(pics: PictureDB, hash, filename: string, width, height: int, date, thumbnail: string, duplicate: bool) =
    pics.exec(sql"INSERT INTO pictures (hash, path, width, height, date, thumbnail, duplicate) VALUES (?, ?, ?, ?, ?, ?, ?)", hash, filename, width, height, date, thumbnail, duplicate)

proc hasPath*(pics: PictureDB, path: string): bool =
    let found = pics.getRow(sql"SELECT 1 FROM pictures WHERE path = ?", path)
    return (found[0] == "1")

proc hasHash*(pics: PictureDB, hash: string): bool =
    let found = pics.getRow(sql"SELECT 1 FROM pictures WHERE hash = ?", hash)
    return (found[0] == "1")

proc getIds*(pics: PictureDB): seq[string] =
  return pics.getAllRows(sql"""SELECT id FROM pictures WHERE duplicate = 'false' ORDER BY date DESC""").mapIt(it[0])
  #pics.exec(sql"DROP TABLE bydate")
  #pics.exec(sql"CREATE TABLE bydate AS SELECT id FROM pictures WHERE duplicate is NULL or duplicate != 'true' ORDER BY date DESC")

proc getThumbnails*(pics: PictureDB, ids: openarray[string]): seq[Picture] =
  let query = "SELECT id, thumbnail, path, date, hash FROM pictures WHERE id IN (" & repeat("?", ids.len).join(",") & ")"
  for row in pics.fastRows(sql(query), args=ids):
    result.add(Picture(id: row[0].parseInt, thumbnail: row[1], path: row[2], date: row[3], hash: row[4]))

when isMainModule:
  import std/os

  if paramCount() != 1:
    echo "usage: " &  getAppFilename() & " <directory>"
    quit(1)

  let dir = paramStr(1)
  var pics = newPictureDB(dir / "db.sqlite")

  #for pic in pics.list():
  #  echo (pic.width, pic.height, pic.date, pic.hash, pic.duplicate)
  echo pics.len
  #echo pics.hasHash("00CB27B89005C08F")
  for pic in pics.getThumbnails(@["2", "3"]):
    echo pic.path
  


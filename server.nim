import os
import json
import strutils

import web
import picture_db
import crawler

if paramCount() != 3:
  echo "usage: " &  getAppFilename() & " <port> <user:password> <directory>"
  quit(1)

let 
  port = paramStr(1).parseInt
  credentials = paramStr(2)
  dir = paramStr(3)

var db = newPictureDB(dir / "db.sqlite")
var app = newApp(credentials)

app.static("/pictures", dir)

var crawl = newCrawler(db, dir)
crawl.start()

const client = slurp("client.js")

app.get("/images", proc(req: Request) {.async.} =
  let requested = req.url.query.split(',')
  echo req.url.path, ' ', req.url.query
  let data = %*[]
  for pic in db.getThumbnails(requested):
    var pic = pic
    pic.path = "/pictures/" & pic.path
    data.add(%*pic)

  let headers = newHttpHeaders([("Content-Type","application/json")])
  await req.respond(Http200, $data, headers)
)

app.get("/", proc(req: Request) {.async.} =
  let ids = db.getIds()

  let data = "<!DOCTYPE html><html><head><script>var image_ids = [" & ids.join(",") & "]; " & client & "</script></head><body></body></html>"
  await req.respond(Http200, data)
)

waitFor app.run(port)

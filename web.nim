# Really basic web framework
import asynchttpserver, asyncdispatch
import asyncnet
import os
import strutils
import asyncfile
import base64
import uri

const chunk_size = 128 * 1024

proc sendFile*(req: Request, filename: string){.async.} =
  var file = openAsync(filename)
  let size = file.getFileSize()

  var msg = "HTTP/1.1 200\c\L"
  msg.add("Content-Length: ")
  msg.addInt size
  msg.add "\c\L"
  msg.add "Cache-Control: public, maxage=31536000\c\L"
  msg.add "Connection: close\c\L"
  msg.add "\c\L"
  await req.client.send(msg)
  var remaining = size
  var buffer = newSeq[byte](chunk_size)
  while remaining > 0:
    let read = await file.readBuffer(addr buffer[0], chunk_size)
    await req.client.send(addr buffer[0], read)
    remaining -= read
  file.close()

proc sendFileSync*(req: Request, filename: string){.async.} =
  var contents = readFile(filename)
  await req.respond(Http200, contents)

type Route = ref object
  path: string
  cb: proc(req: Request){.async.}

type App* = ref object
  server: AsyncHttpServer
  routes: seq[Route]
  staticRoutes: seq[tuple[path, dest: string]]
  password: string

proc checkAuth(app: App, req: Request): Future[bool] {.async, gcsafe.} =
  if not req.headers.hasKey("Authorization"):
    let realm = "Authentication required" 
    let headers = newHttpHeaders([("WWW-Authenticate", "Basic realm=\"" & realm & "\", charset=\"UTF-8\"") ])
    await req.respond(Http401, "Unauthorized", headers)
    return false
  else:
    let token = base64.decode(req.headers["Authorization"].split()[^1])
    if token == app.password:
      return true
    await req.respond(Http403, "Access denied")
    return false

proc newApp*(password=""): App =
  result = App(password: password, server: newAsyncHttpServer())

proc get*(app: var App, path: string, cb: proc(req: Request){.async.}) =
  let route = Route(path: path, cb: cb)
  app.routes.add(route)

proc static*(app: var App, path, dest: string) =
  app.staticRoutes.add((path, dest))

proc run*(app: App, port=8080) {.async.} =
  proc cb(req: Request) {.async, gcsafe.} =
    if app.password != "":
      if not await app.checkAuth(req):
        return
    for route in app.routes:
      if route.path == req.url.path:
        await route.cb(req)
        return
    let decodedPath = decodeUrl(req.url.path).replace("..", "")
    for (path, dest) in app.staticRoutes:
      echo (path, dest, decodedPath, decodedPath.startsWith(path))
      if decodedPath.startsWith(path):
        let filename = dest / decodedPath[path.len .. ^1]
        echo filename
        if fileExists(filename):
          await req.sendFile(filename)
    await req.respond(Http404, "Not Found")
  await app.server.serve(Port(port), cb)

export asynchttpserver, asyncdispatch

when isMainModule:
  var app = newApp()
  app.get("/", proc(req: Request) {.async.} =
    await req.respond(Http200, "Hello")
  )
  app.static("/public")

  waitFor app.run()


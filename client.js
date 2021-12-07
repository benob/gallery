let element_width = 244;
let element_height = 244;
var images = {};

function handle_click(e) {
  let link = e.target.getAttribute('data-url');
  window.location = link;
}

function handle_resize(e) {
  let num_elements = image_ids.length;
  let body = document.body;
  rect = body.getBoundingClientRect();
  let num_width = Math.round(rect.width / element_width);
  let height = element_height * Math.floor(num_elements / num_width);
  document.body.style.height = height + 'px';
  rect = body.getBoundingClientRect();
  let offset = (window.innerWidth - num_width * element_width) / 2;
  if (e.type === 'resize') {
    for(id in images) {
      let img = images[id].img;
      //console.log(images[id]);
      if (img !== null) {
        let index = images[id].index;
        let i = index % num_width;
        let j = Math.floor(index / num_width);
        img.style.left = (i * element_width + offset) + 'px';
        img.style.top = (j * element_height) + 'px';
      }
    }
  }
  let start_x = Math.max(0, Math.floor(-rect.x / element_width));
  let end_x = Math.min(Math.floor(window.innerWidth / element_width), Math.floor((-rect.x + window.innerWidth) / element_width));
  let start_y = Math.max(0, Math.floor(-rect.y / element_height)) - 5;
  let end_y = Math.min(Math.floor(rect.height / element_height), Math.floor((-rect.y + window.innerHeight) / element_height)) + 5;

  let collected = [];
  for(let i = start_x; i < end_x; i++) {
    for(let j = start_y; j < end_y; j++) {
      let id = i + j * num_width;
      if (id >= 0 && id < num_elements) {
        let mapped = image_ids[id];
        if (!(mapped in images)) {
          images[mapped] = {index: id, status: 'loading', img: null};
          collected.push(mapped);
        }
      }
    }
  }
  if ( collected.length > 0 ) {
    fetch('/images?' + collected.sort().join(','))
      .then(response => response.json())
      .then(data => {
        data.forEach((found) => {
          //console.log('FOUND', found);
          let id = images[found.id].index;
          let img = document.createElement('img')
          img.width = element_width;
          img.height = element_height;
          img.style.position = 'absolute';
          let i = id % num_width;
          let j = Math.floor(id / num_width);
          img.style.left = (i * element_width + offset) + 'px';
          img.style.top = (j * element_height) + 'px';
          img.src = "data:image/jpeg;base64," + found.thumbnail;
          img.setAttribute('data-url', found.path);
          img.style.cursor = 'pointer';
          img.onclick = handle_click;
          img.setAttribute('alt', found.date);
          img.setAttribute('data-id', found.hash);
          images[found.id].img = img;
          images[found.id].status = 'loaded';
          document.body.appendChild(img);
        })
      });
  }
}

window.onresize = handle_resize;
window.onscroll = handle_resize;

document.addEventListener('DOMContentLoaded', () => {
  handle_resize({type: 'resize'});
  document.body.style.background = 'black';
});

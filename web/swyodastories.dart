// http://www.zachtronics.com/yoda-stories/
// https://github.com/digitall/scummvm-deskadv
// +Me!

import 'dart:html';
import 'dart:typed_data';

import 'BinaryReader.dart';
import 'Palette.dart';

const planetTypes = const ['', 'desert', 'snow', '', 'forest', 'swamp'];
const planetColors = const['', 'LightYellow', 'LightBlue', '', 'DarkOliveGreen', 'DarkOliveGreen'];

class MapInfo {
  int type;
  int x;
  int y;
  int arg;
}

class Zone {
  int _id;
  int _width;
  int _height;
  int _flags;
  int _planet;
  List<List<Tile>> tiles;
  List<MapInfo> mapInfos;
  
  Zone(int width, int height) {
    _width = width;
    _height = height;
    tiles = new List(3);
    tiles[0] = new List(width * height);
    tiles[1] = new List(width * height);
    tiles[2] = new List(width * height);
    mapInfos = new List();
  }

  drawHint(CanvasRenderingContext2D canvas2D, MapInfo mapInfo) {
    canvas2D.fillStyle = 'rgba(255, 255, 255, 0.5)';
    canvas2D.fillRect(mapInfo.x * 32, mapInfo.y * 32, 32, 32);
  }
  
  draw(CanvasRenderingContext2D canvas2D) {
    for (int y = 0; y < _height; y++) {
      for (int x = 0; x < _width; x++) {
        for (int l = 0; l < 3; l++) {
          Tile tile = tiles[l][x + y * _width];
          if (tile != null)
            tile.paint(canvas2D, x, y, blend: l > 0);
        }
      }
    }
    mapInfos.forEach((e) => drawHint(canvas2D, e));
  }
}

class Tile {
  Uint32List _data;
  Uint8List _data8;
  int flags;
  static final CanvasElement _tempCanvas = new CanvasElement(width: 32, height: 32);
  static final CanvasRenderingContext2D _tempContext2D = _tempCanvas.context2D;
  static final ImageData _imageData = _tempContext2D.createImageData(32, 32);
  
  Tile(BinaryReader reader) {
    _data = new Uint32List(32 * 32);
    flags = reader.getUint32();
    for (int j = 0; j < 0x400; j++) {
      _data[j] = Palette.palette32[reader.getUint8()];
    }
    _data8 = new Uint8List.view(_data.buffer);
  }

  paint(CanvasRenderingContext2D canvas2D, int x, int y, {bool blend: true}) {
    if (blend) {    
      _imageData.data.setRange(0, _data8.length, _data8);
      _tempContext2D.putImageData(_imageData, 0, 0);
      canvas2D.drawImage(_tempCanvas, x * 32, y * 32);      
    } else {
      _imageData.data.setRange(0, _data8.length, _data8);
      canvas2D.putImageData(_imageData, x * 32, y * 32);
    }
  }
}

class Game {
  BinaryReader reader;
  int version;
  List<Tile> tiles;
  List<String> tileNames;
  List<String> sounds;
  List<Zone> zones;
  Uint8List setupScreen;
  
  CanvasElement canvas;
  CanvasRenderingContext2D canvas2D;

  Game(CanvasElement canvas, ByteData data) {
    this.canvas = canvas;
    this.canvas2D = canvas.context2D;
    canvas2D.setFillColorRgb(255, 0, 0);
    reader = new BinaryReader(data);
    tiles = new List();
    tileNames = new List();
    sounds = new List();
    zones = new List();
    init();
  }

  init() {
    String section;
    while (section != 'ENDF') {
      section = reader.getTag();
      switch (section) {
        case 'ENDF':
          break;
        case 'STUP':
          int length = reader.getUint32();
          setupScreen = reader.getByteArray(length);
          break;
        case 'VERS':
          version = reader.getInt32();
          break;
        case 'SNDS': // SouNDS
          int size = reader.getUint32();
          int count = -reader.getInt16();
          for (int i = 0; i < count; i++) {
            int size = reader.getUint16();
            String sound = reader.getString(size);
            sounds.add(sound);
          }
          assert(sounds.length == count);
          break;
        case 'ZONE':
          var count = reader.getUint16();
          for (int i = 0; i < count; i++) {
            int headPos = reader.pos;
            int z1 = reader.getUint16();
            assert([1, 2, 3, 5].contains(z1));
            int zoneLength = reader.getUint32(); // asserted later
            int zoneId = reader.getUint16();
            assert(zoneId == i);

            String tag = reader.getString(4);
            assert(tag == "IZON");
            int size = reader.getUint32();
            int width = reader.getUint16();
            int height = reader.getUint16();
            assert(width * height * 6 + 20 == size);
            
            Zone z = new Zone(width, height);
            z._id = zoneId;
            z._flags = reader.getUint8();
            
            int tmp = reader.getUint32();
            assert(tmp == 0xFF000000);
            tmp = reader.getUint8();
            assert(tmp == 255);
            
            z._planet = reader.getUint8();
            
            tmp = reader.getUint8();
            assert(tmp == 0);
            
            for (int j = 0; j < height; j++) {
              for (int k = 0; k < width; k++) {
                for (int t = 0; t < 3; t++) {
                  int tnum = reader.getUint16();
                  z.tiles[t][(j * width) + k] = tnum == 0xFFFF ? null : tiles[tnum];
                }
              }
            }
            zones.add(z);

            int mapInfoCount = reader.getUint16();
            for (int j = 0; j < mapInfoCount; j++) {
              MapInfo mapInfo = new MapInfo();
              mapInfo.type = reader.getUint32();
              mapInfo.x = reader.getUint16();
              mapInfo.y = reader.getUint16();
              mapInfo.arg = reader.getUint32();
              z.mapInfos.add(mapInfo);
            }

            tag = reader.getTag();
            assert(tag == "IZAX");
            tmp = reader.getUint32();
            assert(tmp >= 16 && tmp <= 1124);
            tmp = reader.getUint16();
            assert(tmp == 0 || tmp == 1);

            int izaxCount1 = reader.getUint16();
            for (int j = 0; j < izaxCount1; j++) {
              reader.skip(44);
            }
            
            int izaxCount2 = reader.getUint16();
            assert([0, 1, 2, 4, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
                    16, 17, 18, 19, 20, 21, 23, 24, 26, 27, 28, 29, 30, 31, 32,
                    33, 34, 36, 38, 40, 43,44, 45, 46, 47, 50, 51, 53, 54,
                    61, 64, 70, 71].contains(izaxCount2));
            reader.skip(2 * izaxCount2);
            
            int izaxCount3 = reader.getUint16();
            assert([0, 1, 2, 3].contains(izaxCount3));
            reader.skip(2 * izaxCount3);

            tag = reader.getTag();
            assert(tag == "IZX2");
            int izx2 = reader.getUint32(); // ignore
            int izx2Count = reader.getUint16();
            assert((izx2Count * 2 + 10) == izx2);
            reader.skip(2 * izx2Count);

            tag = reader.getTag();
            assert(tag == "IZX3");
            int izx3 = reader.getUint32();
            int izx3Count = reader.getUint16();
            assert([0x0A, 0x0C, 0x1E, 0x26, 0x28, 0x2A, 0x2C, 0x2E, 0x30,
                    0x34, 0x36, 0x38, 0x3C, 0x40, 0x44, 0x46, 0x4A,
                    0x4C, 0x4E, 0x50, 0x52, 0x54].contains(izx3));
            assert((izx3Count * 2 + 10) == izx3);
            reader.skip(2 * izx3Count);

            tag = reader.getTag();
            assert(tag == "IZX4");
            int izx4_1 = reader.getUint32();
            assert(izx4_1 == 2);
            int izx4_2 = reader.getUint16();
            assert([0, 1].contains(izx4_2));

            // IACTs
            int iactCount = reader.getUint16();
            for (int j = 0; j < iactCount; j++) {
              tag = reader.getTag();
              assert(tag == "IACT");
              int temp = reader.getUint32(); // ignore
              int iactItemCount1 = reader.getUint16();
              for (int k = 0; k < iactItemCount1; k++) {
                reader.skip(2 * 7);
              }
              int iactItemCount2 = reader.getUint16();
              for (int k = 0; k < iactItemCount2; k++) {
                reader.skip(2 * 6);
                int slen = reader.getUint16();
                String s = "none";
                if (slen > 0) {
                  s = reader.getString(slen);
                  //print(k.toString() + " " + s);
                }
              }
            }
            assert(reader.pos - headPos == zoneLength + 6);
          }
          break;
        case 'TNAM': // Tile NAMe
          int sectionLength = reader.getUint32();
          while (true) {
            int id = reader.getUint16();
            if (id == 0xffff)
              break;
            String name = reader.getString(24);
            //print(id.toString() + " " + name);
            tileNames.add(name);
          }
          assert(tileNames.length == (sectionLength - 2) / 26);
          break;
        case 'TILE':
          int tileSectionLength = reader.getUint32();
          for (int i = 0; i < tileSectionLength / 0x404; i++) {        
            tiles.add(new Tile(reader));
          }
          break;
        default:
          int size = reader.getUint32();
          reader.skip(size);
          print("Unhandled section: " + section + " size: " + size.toString());
      }
    }
  }
  
  drawSetup() {
    print("drawSetup");
    print(setupScreen.length);
    print(32*9*33*9);
    print(setupScreen.buffer.asUint16List()[0]);
    Uint32List screen = new Uint32List(9 * 32 * 9 * 32);
    Uint32List palette32 = Palette.palette32;
    for (int y = 0; y < 9 * 32; y++) {
        for (int x = 0; x < 9 * 32; x++) {
          int pixelData = setupScreen[(y*32*9)+x];
          screen[(y * 9 * 32) + x] = palette32[pixelData];
        }
    }
    ImageData imageData = canvas2D.createImageData(32 * 9, 32 * 9);
    imageData.data.setRange(0, 32*9*32*9 * 4, screen.buffer.asUint8List());
    canvas2D.putImageData(imageData, 0, 0);
  }
  
  paintTile(int x, int y, int tileId, {bool blend: true}) {
    Tile tile = tiles[tileId].paint(canvas2D, x, y, blend: blend);
  }
  
  drawZone(int z) {
    document.body.style.backgroundColor = planetColors[zones[z]._planet];
    canvas2D.clearRect(0, 0, canvas.width, canvas.height);
    zones[z].draw(canvas2D);
  }
  
  status() {
    print("Tiles: " + tiles.length.toString());
    print("Tile names: " + tileNames.length.toString());
    print("Zones: " + zones.length.toString());
    print("Sounds: " + sounds.length.toString());
  }
}

Game game;

void main() {
  HttpRequest.request('YODESK.DTA', responseType: 'arraybuffer').then((HttpRequest req) {
    game = new Game((querySelector("#canvas") as CanvasElement), 
        new ByteData.view(req.response));
    //game.drawSetup();
    //game.paintTile(5, 5, 1024, blend: true);
    game.drawZone(277);
    game.status();
    SelectElement zones = querySelector("#zones") as SelectElement;
    game.zones.forEach((e) => zones.children.add(
        new OptionElement(value: e._id.toString(), data: e._id.toString())));
    zones.onChange.listen((e) =>
        game.drawZone(int.parse(zones.selectedOptions.first.value)));
    print("Everything is OK");
  });
}

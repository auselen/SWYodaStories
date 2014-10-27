// http://www.zachtronics.com/yoda-stories/
// https://github.com/digitall/scummvm-deskadv
// +Me!

/*
 * TODO:
 * Figure out fireplace animation at zone 535.
 */

import 'dart:html';
import 'dart:typed_data';

import 'BinaryReader.dart';
import 'Palette.dart';

var debugGame = false;

const planetTypes = const ['', 'desert', 'snow', '', 'forest', 'swamp'];
const planetColors = const['', 'LightYellow', 'LightBlue', '', 'DarkOliveGreen', 'DarkOliveGreen'];

Map<int, String> tileNames;

class MapInfo {
  int type;
  int x;
  int y;
  int arg;
}

class IACT {
  List<Uint8List> data1;
  List<Uint8List> data2;
  List<String> strs;
  
  IACT() {
    data1 = new List();
    data2 = new List();
    strs = new List();
  }
  
  toString() {
    StringBuffer sb = new StringBuffer();
    if (data1 != null) {
      sb.write("data1 [" + data1.length.toString() + "]:\n");
      data1.forEach((e) {sb.write(" "); sb.write(e); sb.write("\n");});
    }
    if (data2 != null) {
      sb.write("data2 [" + data2.length.toString() + "]:\n");
      data2.forEach((e) {sb.write(" "); sb.write(e); sb.write("\n");});
    }
    if (strs != null) {
      sb.write("strs [" + strs.length.toString() + "]:\n");
      strs.forEach((e) {sb.write(" "); sb.write(e); sb.write("\n");});
    }
    return sb.toString();
  }
}

class Zone {
  int _id;
  int _width;
  int _height;
  int _flags;
  int _planet;
  List<List<Tile>> tiles;
  List<MapInfo> mapInfos;
  List<IACT> iacts;
  
  int _izax_unknown1;
  int _izax_unknown2;
  Uint8List _izax_buffer;
  Uint8List _izax_buffer2;
  Uint8List _izax_buffer3;
  int _izx2;
  Uint8List _izx2_data;
  int _izx3;
  Uint8List _izx3_data;
  int _izx4_1;
  int _izx4_2;
  
  Zone(int width, int height) {
    _width = width;
    _height = height;
    tiles = new List(3);
    tiles[0] = new List(width * height);
    tiles[1] = new List(width * height);
    tiles[2] = new List(width * height);
    mapInfos = new List();
    iacts = new List();
  }

  toString() {
    StringBuffer sb = new StringBuffer();
    sb.write("zone  :" + _id.toString());
    sb.write("\n");
    sb.write("flags :0x" + _flags.toRadixString(16));
    sb.write("\n");
    sb.write("izax1 :" + _izax_unknown1.toString());
    sb.write("\n");
    sb.write("izax2 :" + _izax_unknown2.toString());
    sb.write("\n");
    sb.write("izax_buffer :" + _izax_buffer.toString());
    sb.write("\n");
    sb.write("izax_buffer2 :" + _izax_buffer2.toString());
    sb.write("\n");
    sb.write("izax_buffer3 :" + _izax_buffer3.toString());
    sb.write("\n");
    sb.write("izx2 :" + _izx2.toString());
    sb.write("\n");
    sb.write("izx2_data :" + _izx2_data.toString());
    sb.write("\n");
    sb.write("izx3 :" + _izx3.toString());
    sb.write("\n");
    sb.write("izx3_data :" + _izx3_data.toString());
    sb.write("\n");
    sb.write("izx4_1 :" + _izx4_1.toString());
    sb.write("\n");
    sb.write("izx4_2 :" + _izx4_2.toString());
    sb.write("\n");
    sb.write("iacts");
    sb.write("\n");
    iacts.forEach((e) { sb.write(e);});
    return sb.toString();
  }

  drawMapInfo(CanvasRenderingContext2D canvas2D, MapInfo mapInfo) {
    canvas2D.fillStyle = 'rgba(255, 255, 255, 0.5)';
    canvas2D.fillRect(mapInfo.x * 32, mapInfo.y * 32, 32, 32);
    canvas2D.font = "16pt Courrier";
    canvas2D.fillStyle = 'rgba(0, 0, 0, 1)';
    canvas2D.fillText(mapInfo.type.toRadixString(16).toUpperCase(),
        mapInfo.x *32 + 8, mapInfo.y * 32 + 24);
    print("mapInfo type: 0x" + mapInfo.type.toRadixString(16) + " arg: 0x" + mapInfo.arg.toRadixString(16) + " pos:" + mapInfo.x.toString() + "," + mapInfo.y.toString());
  }

  draw(CanvasRenderingContext2D canvas2D) {
    for (int y = 0; y < _height; y++) {
      for (int x = 0; x < _width; x++) {
        for (int l = 0; l < 3; l++) {
          Tile tile = tiles[l][x + y * _width];
          if (tile != null) {
            if (debugGame) {
              //print("tile at " + x.toString() + ", " + y.toString() + ", " + l.toString() + " " + tile._id.toString());
            }
            tile.paint(canvas2D, x, y, blend: l > 0);
            if (debugGame)
              if (tileNames[tile._id] != null) {
                if (tile._id == 355) { // Invis.Blocker
                  canvas2D.fillStyle = 'rgba(255, 0, 0, 0.5)';
                  canvas2D.fillRect(x * 32, y * 32, 32, 32);
                }
                print("drawn tile #" + tile._id.toString() +
                    " " + tileNames[tile._id] +
                    " x:" + x.toString() + " y:" + y.toString() + " l:" + l.toString());
              }
          }
        }
      }
    }
    if (debugGame) {
      mapInfos.forEach((e) => drawMapInfo(canvas2D, e));
      print(this);
    }
  }
}

class Tile {
  int _id;
  Uint32List _data;
  Uint8List _data8;
  int flags;
  static final CanvasElement _tempCanvas = new CanvasElement(width: 32, height: 32);
  static final CanvasRenderingContext2D _tempContext2D = _tempCanvas.context2D;
  static final ImageData _imageData = _tempContext2D.createImageData(32, 32);
  
  Tile(int id, BinaryReader reader) {
    _id = id;
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

class IPUZ {
  int v1;
  int v2;
  int v3;
  int v4;
  String text;
  Uint8List data;
  int item; // matches tile name
  
  toString() {
    StringBuffer sb = new StringBuffer();
    sb.write("v1: 0x" + v1.toRadixString(16));
    sb.write("\nv2: 0x" + v2.toRadixString(16));
    sb.write("\nv3: 0x" + v3.toRadixString(16));
    sb.write("\nv4: 0x" + v4.toRadixString(16));
    sb.write("\n text: " + text);
    sb.write("\n item: " + item.toString());
    sb.write("\n data: " + data.toString());
    return sb.toString();
  }
}

class ICHA {
  String name;
  Uint8List data;
  Uint8List data2;
  
  toString() {
    StringBuffer sb = new StringBuffer();
    sb.write("icha: ");
    sb.write(name);
    sb.write("\n");
    sb.write(data);
    sb.write("\n");
    sb.write(data2);
    return sb.toString();
  }
}

class Game {
  BinaryReader reader;
  int version;
  List<Tile> tiles;
  List<String> sounds;
  List<Zone> zones;
  Uint8List setupScreen;
  List<IPUZ> ipuzs;
  List<ICHA> ichas;
  
  CanvasElement canvas;
  CanvasRenderingContext2D canvas2D;

  Game(CanvasElement canvas, ByteData data) {
    this.canvas = canvas;
    this.canvas2D = canvas.context2D;
    canvas2D.setFillColorRgb(255, 0, 0);
    reader = new BinaryReader(data);
    tiles = new List();
    tileNames = new Map();
    sounds = new List();
    zones = new List();
    ipuzs = new List();
    ichas = new List();
    init();
  }

  init() {
    String section;
    while (section != 'ENDF') {
      section = reader.getTag();
      print("Processing section: " + section);
      switch (section) {
        case 'ENDF':
          break;
        case 'STUP':
          int length = reader.getUint32();
          setupScreen = reader.getByteArray(length);
          break;
        case 'VERS':
          version = reader.getInt32();
          assert(version == 0x00000200);
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
          print("parsed # sound file names: " + sounds.length.toString());
          break;
        case 'ZONE':
          var count = reader.getUint16();
          for (int i = 0; i < count; i++) {
            int headPos = reader.pos;
            int z1 = reader.getUint16(); // same as planet
            int zoneLength = reader.getUint32(); // asserted later
            int zoneId = reader.getUint16();
            if (zoneId == 93) print("93 pos:" + reader.pos.toRadixString(16));
            assert(zoneId == i);

            reader.expectTag("IZON");
            int size = reader.getUint32();
            int width = reader.getUint16();
            int height = reader.getUint16();
            assert(width * height * 6 + 20 == size);
            
            Zone z = new Zone(width, height);
            z._id = zoneId;
            z._flags = reader.getUint8();
            
            int constant = reader.getUint32();
            assert(constant == 0xFF000000);
            constant = reader.getUint8();
            assert(constant == 255);
            
            z._planet = reader.getUint8();
            assert(z._planet == z1);
            
            constant = reader.getUint8();
            assert(constant == 0);
            
            for (int j = 0; j < height; j++) {
              for (int k = 0; k < width; k++) {
                for (int t = 0; t < 3; t++) {
                  int tnum = reader.getUint16();
                  z.tiles[t][(j * width) + k] = tnum == 0xFFFF ? null : tiles[tnum];
                }
              }
            }
            zones.add(z);

            if (zoneId == 93) print("93 pos:" + reader.pos.toRadixString(16));
            
            int mapInfoCount = reader.getUint16();
            for (int j = 0; j < mapInfoCount; j++) {
              MapInfo mapInfo = new MapInfo();
              mapInfo.type = reader.getUint32();
              mapInfo.x = reader.getUint16();
              mapInfo.y = reader.getUint16();
              constant = reader.getUint16();
              assert(constant == 0x01);
              mapInfo.arg = reader.getUint16();
              z.mapInfos.add(mapInfo);
            }

            if (zoneId == 93) print("93 pos:" + reader.pos.toRadixString(16));
            
            reader.expectTag("IZAX");
            int tmp = reader.getUint32();
            z._izax_unknown1 = tmp;
            assert(tmp >= 16 && tmp <= 1124);
            tmp = reader.getUint16();
            z._izax_unknown2 = tmp;
            assert(tmp == 0 || tmp == 1);

            int izaxCount1 = reader.getUint16();
            z._izax_buffer = reader.getByteArray(44 * izaxCount1);

            int izaxCount2 = reader.getUint16();
            assert([0, 1, 2, 4, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
                    16, 17, 18, 19, 20, 21, 23, 24, 26, 27, 28, 29, 30, 31, 32,
                    33, 34, 36, 38, 40, 43,44, 45, 46, 47, 50, 51, 53, 54,
                    61, 64, 70, 71].contains(izaxCount2));
            z._izax_buffer2 = reader.getByteArray(2 * izaxCount2);
            
            int izaxCount3 = reader.getUint16();
            assert([0, 1, 2, 3].contains(izaxCount3));
            z._izax_buffer3 = reader.getByteArray(2 * izaxCount3);

            reader.expectTag("IZX2");
            z._izx2 = reader.getUint32(); // ignore
            int izx2Count = reader.getUint16();
            assert((izx2Count * 2 + 10) == z._izx2);
            z._izx2_data = reader.getByteArray(2 * izx2Count);

            reader.expectTag("IZX3");
            z._izx3 = reader.getUint32();
            int izx3Count = reader.getUint16();
            assert([0x0A, 0x0C, 0x1E, 0x26, 0x28, 0x2A, 0x2C, 0x2E, 0x30,
                    0x34, 0x36, 0x38, 0x3C, 0x40, 0x44, 0x46, 0x4A,
                    0x4C, 0x4E, 0x50, 0x52, 0x54].contains(z._izx3));
            assert((izx3Count * 2 + 10) == z._izx3);
            z._izx3_data = reader.getByteArray(2 * izx3Count);

            reader.expectTag("IZX4");
            z._izx4_1 = reader.getUint32();
            assert(z._izx4_1 == 2);
            z._izx4_2 = reader.getUint16();
            assert([0, 1].contains(z._izx4_2));

            // IACTs
            int iactCount = reader.getUint16();
            for (int j = 0; j < iactCount; j++) {
              reader.expectTag("IACT");
              IACT iact = new IACT();
              int size = reader.getUint32();
              int iactItemCount1 = reader.getUint16();
              for (int k = 0; k < iactItemCount1; k++) {
                iact.data1.add(reader.getByteArray(2 * 7));
              }
              int iactItemCount2 = reader.getUint16();
              for (int k = 0; k < iactItemCount2; k++) {
                iact.data2.add(reader.getByteArray(2 * 6));
                int slen = reader.getUint16();
                if (slen > 0) {
                  String s = reader.getString(slen);
                  iact.strs.add(s);
                }
              }
              z.iacts.add(iact);
            }
            assert(reader.pos - headPos == zoneLength + 6);
            //if (zoneId == 93) print(z);
          }
          break;
        case 'TNAM': // Tile NAMe
          int sectionLength = reader.getUint32();
          while (true) {
            int id = reader.getUint16();
            if (id == 0xffff)
              break;
            String name = reader.getString(24);
            tileNames[id] = name;
          }
          assert(tileNames.length == (sectionLength - 2) / 26);
          break;
        case 'TILE':
          int tileSectionLength = reader.getUint32();
          for (int i = 0; i < tileSectionLength / 0x404; i++) {        
            tiles.add(new Tile(i, reader));
          }
          break;
        case 'PUZ2':
          int puz2SectionLength = reader.getUint32();
          while (true) {
            int id = reader.getUint16();
            if (id == 0xffff)
              break;
            IPUZ ipuz = new IPUZ();
            int pos = reader.pos;
            reader.expectTag("IPUZ");
            int ipuzLen = reader.getUint32();
            ipuz.v1 = reader.getUint32();
            ipuz.v2 = reader.getUint32();
            ipuz.v3 = reader.getUint32();
            ipuz.v4 = reader.getUint16();
            while (reader.pos < (ipuzLen + pos)) {
              int textlen = reader.getUint16();
              if (textlen == 0) {
                continue;
              }
              String text = reader.getString(textlen);
              ipuz.text = text;
            }
            int tmp = reader.getUint16();
            assert(tmp == 0);
            if (ipuz.v4 != 0) {
              tmp = reader.getUint16();
              assert(tmp == 0);
            }
            ipuz.item = reader.getUint16();
            ipuz.data = reader.getByteArray(0x2);
            // data[0] is item
            ipuzs.add(ipuz);
            assert(ipuzs.length == (id + 1));
          }
          break;
        case 'CHAR':
          int charLen = reader.getUint32();
          while (true) {
            int id = reader.getUint16();
            if (id == 0xffff)
              break;
            reader.expectTag('ICHA');
            ICHA icha = new ICHA();
            int len = reader.getInt32();
            assert(len == 0x4a);
            icha.name = reader.getCString();
            icha.data = reader.getByteArray(0x2a - (icha.name.length + 1));
            icha.data2 = reader.getByteArray(0x20);
            ichas.add(icha);
            //print(icha);
            assert(ichas.length == (id + 1));
          }
          break;
        default:
          int pos = reader.pos;
          int size = reader.getUint32();
          reader.skip(size);
          print("Unhandled section: " + section + " start: 0x" + pos.toRadixString(16) + " size: " + size.toString());
      }
    }
  }
  
  drawSetup() {
    Uint32List screen = new Uint32List(9 * 32 * 9 * 32);
    Uint32List palette32 = Palette.palette32;
    for (int y = 0; y < 9 * 32; y++) {
        for (int x = 0; x < 9 * 32; x++) {
          int pixelData = setupScreen[(y * 9 * 32) + x];
          screen[(y * 9 * 32) + x] = palette32[pixelData];
        }
    }
    ImageData imageData = canvas2D.createImageData(32 * 9, 32 * 9);
    imageData.data.setRange(0, 32 * 9 * 32 * 9 * 4, screen.buffer.asUint8List());
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
    game.drawZone(0);
    game.status();
    SelectElement zones = querySelector("#zones") as SelectElement;
    game.zones.forEach((e) => zones.children.add(
        new OptionElement(value: e._id.toString(), data: e._id.toString() + " " + e._id.toRadixString(16))));
    zones.onChange.listen((e) =>
        game.drawZone(int.parse(zones.selectedOptions.first.value)));
    CheckboxInputElement debug = querySelector("#debugGame") as CheckboxInputElement;
    if (debug == null)
      print("debug is null");
    else
    debug.onChange.listen((e) {
      debugGame = debug.checked;
      game.drawZone(int.parse(zones.selectedOptions.first.value));
    });
    print("Everything is OK (but not awesome)!");
  });
}

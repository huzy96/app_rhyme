// import 'dart:async';
// import 'package:app_rhyme/main.dart';
// import 'package:app_rhyme/src/rust/api/mirror.dart';
// import 'package:app_rhyme/types/music.dart';
// import 'package:get/get.dart';

// class MusicQueue extends GetxController {
//   final RxList<Music> musicList = RxList<Music>([]);
//   final Rx<Music?> currentlyPlaying = Rx<Music?>(null);
//   final Rx<PlayInfo?> currentlyPlayingPlayinfo = Rx<PlayInfo?>(null);
//   MusicQueue();

//   // 添加播放新音乐(已存在则调整至最后)
//   Future<Music?> addMusic(
//     Music music,
//   ) async {
//     // 需要将MusicTuple扩充成MusicTuple，才具备播放能力
//     Music? newMusic = await display2Music(music);
//     if (newMusic == null) {
//       return null;
//     }
//     var existingIndex = musicList.indexWhere((m) => m.extra == newMusic.extra);
//     if (existingIndex != -1) {
//       // 如果音乐已经存在，移动到列表末尾
//       var existingMusic = musicList.removeAt(existingIndex);
//       musicList.add(existingMusic);
//       currentlyPlaying.value = existingMusic;
//       currentlyPlayingPlayinfo.value = existingMusic.playInfo;
//       update();
//     } else {
//       // 如果音乐不存在，添加到列表并设置为当前播放
//       try {
//         var newMusic = await display2Music(music);
//         musicList.add(newMusic);
//         currentlyPlaying.value = newMusic;
//         currentlyPlayingPlayinfo.value = newMusic.playInfo;
//         update();
//       } catch (e) {
//         log("Faild to build music tuple: $e");
//         return null;
//       }
//     }
//     return currentlyPlaying.value;
//   }

//   Future<Music?> replaceMusic(Music newMusic) async {
//     try {
//       // 查找具有相同extra的音乐索引
//       int index = musicList.indexWhere((m) => m.extra == newMusic.extra);
//       if (index != -1) {
//         // 如果找到，替换旧的Music
//         musicList[index] = newMusic;
//         // 检查是否正在播放这首音乐
//         if (currentlyPlaying.value?.extra == newMusic.extra) {
//           currentlyPlaying.value = newMusic;
//           currentlyPlayingPlayinfo.value = newMusic.playInfo;
//         }
//         update();
//         return currentlyPlaying.value;
//       } else {
//         log("未找到具有相同extra的音乐");
//         return null;
//       }
//     } catch (e) {
//       log("替换音乐时出错: $e");
//       return null;
//     }
//   }

//   Future<Music?> replaceAllMusics(
//     List<Music> musics,
//   ) async {
//     musicList.clear();
//     update();
//     for (var music in musics) {
//       musicList.add(await display2Music(music));
//     }
//     var firstMusic = _getIndex(0);
//     currentlyPlaying.value = firstMusic;
//     currentlyPlayingPlayinfo.value = firstMusic?.playInfo;
//     update();
//     return firstMusic;
//   }

//   // 这里我们认为跳到同一首歌也是改变了(改变进度从头开始)
//   Music? skipToMusic(int index) {
//     var music = _getIndex(index);
//     if (music != null) {
//       currentlyPlaying.value = music;
//       currentlyPlayingPlayinfo.value = music.playInfo;
//       update();
//       return currentlyPlaying.value;
//     } else {
//       log("try to play invaild index:$index music");
//       return null;
//     }
//   }

//   // 播放下一首音乐
//   Music? skipToNext() {
//     if (musicList.isNotEmpty) {
//       int currentIndex = currentlyPlaying.value != null
//           ? musicList.indexOf(currentlyPlaying.value!)
//           : -1;
//       int nextIndex = (currentIndex + 1) % musicList.length; // 循环播放
//       currentlyPlaying.value = musicList[nextIndex];
//       currentlyPlayingPlayinfo.value = musicList[nextIndex].playInfo;
//       update();
//       return currentlyPlaying.value;
//     } else {
//       log("try to play next music, but no music found");
//       return null;
//     }
//   }

//   // 播放上一首音乐
//   Music? skipToPrevious() {
//     if (musicList.isNotEmpty) {
//       int currentIndex = currentlyPlaying.value != null
//           ? musicList.indexOf(currentlyPlaying.value!)
//           : musicList.length;
//       int previousIndex =
//           (currentIndex - 1 + musicList.length) % musicList.length; // 循环播放
//       currentlyPlaying.value = musicList[previousIndex];
//       currentlyPlayingPlayinfo.value = musicList[previousIndex].playInfo;
//       update();
//       return currentlyPlaying.value;
//     } else {
//       log("try to play previous music, but no music found");
//       return null;
//     }
//   }

//   // 删除指定索引的音乐
//   Music? delIndex(int index) {
//     try {
//       if (currentlyPlaying.value == musicList[index]) {
//         currentlyPlaying.value = null;
//         currentlyPlayingPlayinfo.value = null;
//         update();
//         log("del playingMusic, stop playiing");
//       }
//       musicList.removeAt(index);
//       update();
//       return currentlyPlaying.value;
//     } catch (_) {
//       log("try to del music of index:$index, but not found.");
//     }
//     return null;
//   }

//   Future<Music?> _changePlayingMusicQuality(
//     int index,
//     Quality quality,
//   ) async {
//     var music = _getIndex(index);
//     if (music != null) {
//       try {
//         if (globalExternApi == null) {
//           log("无第三方音乐源,无法获取播放信息");
//           throw Exception("无第三方音乐源,无法获取播放信息");
//         }
//         var playinfo = await globalExternApi!.getMusicPlayInfo(
//             music.info.source, music.ref.getExtraInto(quality: quality));
//         music.playInfo = playinfo;

//         if (currentlyPlaying.value == music) {
//           currentlyPlaying.value = music;
//           currentlyPlayingPlayinfo.value = music.playInfo;
//           update();
//           return currentlyPlaying.value;
//         }
//       } catch (e) {
//         log("Failed to change quality for $index: $e");
//         return null;
//       }
//     }
//     return null;
//   }

//   // 重新排序音乐,我们不认为重新排序要播放别的，故可以不管
//   void reorderMusic(int oldIndex, int newIndex) {
//     if (oldIndex < newIndex) {
//       newIndex -= 1;
//     }
//     final Music music = musicList.removeAt(oldIndex);
//     musicList.insert(newIndex, music);
//     update();
//   }

//   // 改变当前正在播放的音乐的音质
//   Future<Music?> changeCurrentPlayingQuality(Quality quality) async {
//     if (currentlyPlaying.value != null) {
//       return await _changePlayingMusicQuality(
//           musicList.indexOf(currentlyPlaying.value!), quality);
//     }
//     log("try to change playingMusic quality, but no music is playing");
//     return null;
//   }

//   // 私有方法，用于获取指定索引的音乐
//   Music? _getIndex(int index) {
//     try {
//       return musicList[index];
//     } catch (_) {
//       return null;
//     }
//   }

//   List<Music> downCast() {
//     List<Music> rst = [];
//     for (var m in musicList) {
//       rst.add(Music(m.ref));
//     }
//     return rst;
//   }

//   // 公共属性和方法
//   int get length => musicList.length;
//   RxList<Music> get allMusic => musicList;
// }

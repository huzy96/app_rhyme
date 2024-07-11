// Helper functions for actions

import 'package:app_rhyme/src/rust/api/music_cache.dart';
import 'package:app_rhyme/utils/cache_helper.dart';
import 'package:app_rhyme/utils/global_vars.dart';
import 'package:app_rhyme/utils/logger.dart';
import 'package:app_rhyme/dialogs/music_container_dialog.dart';
import 'package:app_rhyme/dialogs/musiclist_info_dialog.dart';
import 'package:app_rhyme/dialogs/select_local_music_dialog.dart';
import 'package:app_rhyme/pages/local_music_list_grid_page.dart';
import 'package:app_rhyme/pages/local_music_list_page.dart';
import 'package:app_rhyme/pages/online_music_list_page.dart';
import 'package:app_rhyme/src/rust/api/cache.dart';
import 'package:app_rhyme/src/rust/api/factory_bind.dart';
import 'package:app_rhyme/src/rust/api/mirrors.dart';
import 'package:app_rhyme/src/rust/api/type_bind.dart';
import 'package:app_rhyme/types/music_container.dart';
import 'package:app_rhyme/utils/const_vars.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

Future<void> deleteFromMusicList(BuildContext context,
    MusicContainer musicContainer, MusicListW musicListW) async {
  try {
    await SqlFactoryW.delMusics(
        musicListName: musicListW.getMusiclistInfo().name,
        ids: Int64List.fromList([musicContainer.info.id]));
    await globalMusicContainerListPageRefreshFunction();
  } catch (e) {
    LogToast.error("删除音乐失败", "删除音乐'${musicContainer.info.name}'失败: $e",
        "[deleteFromMusicList] Failed to delete music: $e");
  }
}

Future<void> deleteMusicCache(MusicContainer musicContainer) async {
  try {
    if (!await musicContainer.hasCache()) return;
    await deleteMusicCache(musicContainer);
    await globalMusicContainerListPageRefreshFunction();
    LogToast.success("删除缓存成功", "成功删除缓存: ${musicContainer.info.name}",
        "[deleteMusicCache] Successfully deleted cache: ${musicContainer.info.name}");
  } catch (e) {
    LogToast.error("删除缓存失败", "删除缓存'${musicContainer.info.name}'失败: $e",
        "[deleteMusicCache] Failed to delete cache: $e");
  }
}

Future<void> cacheMusicHelper(MusicContainer musicContainer) async {
  try {
    var success = await musicContainer.updateAll();
    if (!success || musicContainer.playInfo == null) {
      return;
    }
    await cacheMusic(
        musicInfo: musicContainer.info, playinfo: musicContainer.playInfo!);
    await globalMusicContainerListPageRefreshFunction();
    LogToast.success("缓存成功", "成功缓存: ${musicContainer.info.name}",
        "[cacheMusic] Successfully cached: ${musicContainer.info.name}");
  } catch (e) {
    LogToast.error("缓存失败", "缓存'${musicContainer.info.name}'失败: $e",
        "[cacheMusic] Failed to cache: $e");
  }
}

Future<void> editMusicInfo(
    BuildContext context, MusicContainer musicContainer) async {
  try {
    var musicInfo = await showMusicInfoDialog(context,
        defaultMusicInfo: musicContainer.info);
    if (musicInfo == null) {
      return;
    }
    await SqlFactoryW.changeMusicInfo(
        musics: [musicContainer.currentMusic], newInfos: [musicInfo]);
    LogToast.success(
        "编辑成功", "编辑音乐信息成功", "[editMusicInfo] Successfully edited music info");
    await globalMusicContainerListPageRefreshFunction();
  } catch (e) {
    LogToast.error("编辑失败", "编辑音乐信息失败: $e",
        "[editMusicInfo] Failed to edit music info: $e");
  }
}

Future<void> viewAlbum(
    BuildContext context, MusicContainer musicContainer) async {
  try {
    var result =
        await musicContainer.currentMusic.fetchAlbum(page: 1, limit: 30);
    var musicList = result.$1;
    var aggs = result.$2;
    if (context.mounted) {
      Navigator.of(context).push(
        CupertinoPageRoute(
            builder: (context) => OnlineMusicListPage(
                  musicList: musicList,
                  firstPageMusicAggregators: aggs,
                )),
      );
    }
  } catch (e) {
    LogToast.error(
        "查看专辑失败", "查看专辑失败: $e", "[viewAlbum] Failed to view album: $e");
  }
}

Future<void> addToMusicList(
    BuildContext context, MusicContainer musicContainer) async {
  var targetMusicList = await showMusicListSelectionDialog(context);
  if (targetMusicList != null) {
    try {
      if (globalConfig.saveLyricWhenAddMusicList) {
        await musicContainer.aggregator.fetchLyric();
      }
      if (globalConfig.savePicWhenAddMusicList &&
          musicContainer.info.artPic != null &&
          musicContainer.info.artPic!.isNotEmpty) {
        cacheFileHelper(musicContainer.info.artPic!, picCacheRoot);
      }
      await SqlFactoryW.addMusics(
          musicsListName: targetMusicList.getMusiclistInfo().name,
          musics: [musicContainer.aggregator]);
      await globalMusicContainerListPageRefreshFunction();

      LogToast.success(
          "添加成功",
          "成功添加'${musicContainer.info.name}'到: ${targetMusicList.getMusiclistInfo().name}",
          "[addToMusicList] Successfully added '${musicContainer.info.name}' to: ${targetMusicList.getMusiclistInfo().name}");
    } catch (e) {
      LogToast.error(
          "添加失败", "添加音乐失败: $e", "[addToMusicList] Failed to add music: $e");
    }
  }
}

Future<void> createNewMusicList(
    BuildContext context, MusicContainer musicContainer) async {
  var newMusicListInfo = await showMusicListInfoDialog(context,
      defaultMusicList: MusicListInfo(
          id: 0,
          name: musicContainer.info.artist.join(","),
          artPic: musicContainer.info.artPic ?? "",
          desc: ""));
  if (newMusicListInfo == null) {
    return;
  }
  if (newMusicListInfo.artPic.isNotEmpty) {
    cacheFileHelper(newMusicListInfo.artPic, picCacheRoot);
  }
  try {
    await SqlFactoryW.createMusiclist(musicListInfos: [newMusicListInfo]);
    if (globalConfig.saveLyricWhenAddMusicList) {
      await musicContainer.aggregator.fetchLyric();
    }
    if (globalConfig.savePicWhenAddMusicList &&
        musicContainer.info.artPic != null &&
        musicContainer.info.artPic!.isNotEmpty) {
      cacheFileHelper(musicContainer.info.artPic!, picCacheRoot);
    }
    await SqlFactoryW.addMusics(
        musicsListName: newMusicListInfo.name,
        musics: [musicContainer.aggregator]);
    globalMusicListGridPageRefreshFunction();
    await globalMusicContainerListPageRefreshFunction();

    LogToast.success("创建成功", "成功创建新歌单: ${newMusicListInfo.name}",
        "[createNewMusicList] Successfully created new music list: ${newMusicListInfo.name}");
  } catch (e) {
    LogToast.error("创建失败", "创建歌单失败: $e",
        "[createNewMusicList] Failed to create music list: $e");
  }
}

Future<void> setAsMusicListCover(
    MusicContainer musicContainer, MusicListW musicListW) async {
  var picLink = musicContainer.info.artPic;
  if (picLink == null || picLink.isEmpty) {
    LogToast.error("设置封面失败", "歌曲没有封面",
        "[setAsMusicListCover] Failed to set cover: music has no cover");
    return;
  }
  var oldMusicListInfo = musicListW.getMusiclistInfo();
  var newMusicListInfo = MusicListInfo(
    name: oldMusicListInfo.name,
    desc: oldMusicListInfo.desc,
    artPic: picLink,
    id: 0,
  );
  try {
    await SqlFactoryW.changeMusiclistInfo(
        old: [oldMusicListInfo], new_: [newMusicListInfo]);
    await globalMusicContainerListPageRefreshFunction();
    globalMusicListGridPageRefreshFunction();
    LogToast.success(
        "设置封面成功", "成功设置为封面", "[setAsMusicListCover] Successfully set as cover");
  } catch (e) {
    LogToast.error("设置封面失败", "设置封面失败: $e",
        "[setAsMusicListCover] Failed to set cover: $e");
  }
}

Future<void> showDetailsDialog(
    BuildContext context, MusicContainer musicContainer) async {
  await showMusicInfoDialog(context, defaultMusicInfo: musicContainer.info);
}

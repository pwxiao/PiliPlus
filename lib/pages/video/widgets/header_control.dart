import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/models/common/super_resolution_type.dart';
import 'package:PiliPlus/models/common/video/audio_quality.dart';
import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/models/common/video/video_decode_type.dart';
import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/pages/common/common_intro_controller.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/switch_item.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/action_item.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/menu_row.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/triple_state.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPlus/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/image_util.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:document_file_save_plus/document_file_save_plus_platform_interface.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:marquee/marquee.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:share_plus/share_plus.dart';

class HeaderControl extends StatefulWidget {
  const HeaderControl({
    required this.isPortrait,
    required this.controller,
    required this.videoDetailCtr,
    required this.heroTag,
    super.key,
  });
  final bool isPortrait;
  final PlPlayerController controller;
  final VideoDetailController videoDetailCtr;
  final String heroTag;

  @override
  State<HeaderControl> createState() => HeaderControlState();
}

class HeaderControlState extends TripleState<HeaderControl> {
  late final PlPlayerController plPlayerController = widget.controller;
  late final VideoDetailController videoDetailCtr = widget.videoDetailCtr;
  late final PlayUrlModel videoInfo = videoDetailCtr.data;
  static const TextStyle subTitleStyle = TextStyle(fontSize: 12);
  static const TextStyle titleStyle = TextStyle(fontSize: 14);
  String get heroTag => widget.heroTag;
  late final UgcIntroController ugcIntroController;
  late final PgcIntroController pgcIntroController;
  @override
  late CommonIntroController introController =
      videoDetailCtr.isUgc ? ugcIntroController : pgcIntroController;
  bool get isPortrait => widget.isPortrait;
  late final horizontalScreen = videoDetailCtr.horizontalScreen;
  RxString now = ''.obs;
  Timer? clock;
  bool get isFullScreen => widget.controller.isFullScreen.value;
  Box setting = GStorage.setting;

  @override
  void initState() {
    super.initState();
    if (videoDetailCtr.isUgc) {
      introController = Get.find<UgcIntroController>(tag: heroTag);
    } else {
      introController = Get.find<PgcIntroController>(tag: heroTag);
    }
  }

  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

  void showBottomSheet(StatefulWidgetBuilder builder, {double? padding}) {
    PageUtils.showVideoBottomSheet(
      context,
      isFullScreen: () => isFullScreen,
      padding: padding,
      child: StatefulBuilder(
        builder:
            (context, setState) =>
                plPlayerController.darkVideoPage
                    ? Theme(
                      data: Theme.of(this.context),
                      child: builder(this.context, setState),
                    )
                    : builder(context, setState),
      ),
    );
  }

  /// 设置面板
  void showSettingSheet() {
    showBottomSheet((context, setState) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          clipBehavior: Clip.hardEdge,
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 14),
            children: [
              ListTile(
                dense: true,
                onTap: () {
                  Get.back();
                  introController.viewLater();
                },
                leading: const Icon(Icons.watch_later_outlined, size: 20),
                title: const Text('添加至「稍后再看」', style: titleStyle),
              ),
              if (videoDetailCtr.epId == null)
                ListTile(
                  dense: true,
                  onTap: () {
                    Get.back();
                    videoDetailCtr.showNoteList(context);
                  },
                  leading: const Icon(Icons.note_alt_outlined, size: 20),
                  title: const Text('查看笔记', style: titleStyle),
                ),
              if (widget.videoDetailCtr.cover.value.isNotEmpty)
                ListTile(
                  dense: true,
                  onTap: () {
                    Get.back();
                    ImageUtil.downloadImg(context, [
                      widget.videoDetailCtr.cover.value,
                    ]);
                  },
                  leading: const Icon(Icons.image_outlined, size: 20),
                  title: const Text('保存封面', style: titleStyle),
                ),
              ListTile(
                dense: true,
                onTap: () {
                  Get.back();
                  PageUtils.scheduleExit(this.context, isFullScreen);
                },
                leading: const Icon(Icons.hourglass_top_outlined, size: 20),
                title: const Text('定时关闭', style: titleStyle),
              ),
              ListTile(
                dense: true,
                onTap: () {
                  Get.back();
                  _showPlayFromLinkDialog();
                },
                leading: const Icon(Icons.link_outlined, size: 20),
                title: const Text('从链接播放', style: titleStyle),
              ),
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.stay_current_landscape_outlined,
                  size: 20,
                ),
                title: Row(
                  children: [
                    const Text(
                      '超分辨率',
                      strutStyle: StrutStyle(leading: 0, height: 1),
                      style: TextStyle(height: 1, fontSize: 14),
                    ),
                    const SizedBox(width: 10),
                    Builder(
                      builder:
                          (context) => PopupMenuButton(
                            initialValue:
                                SuperResolutionType.values[widget
                                    .controller
                                    .superResolutionType],
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    SuperResolutionType
                                        .values[widget
                                            .controller
                                            .superResolutionType]
                                        .title,
                                    strutStyle: const StrutStyle(
                                      leading: 0,
                                      height: 1,
                                    ),
                                    style: TextStyle(
                                      height: 1,
                                      fontSize: 14,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                  Icon(
                                    MdiIcons.unfoldMoreHorizontal,
                                    size: MediaQuery.textScalerOf(
                                      context,
                                    ).scale(14),
                                    color: theme.colorScheme.secondary,
                                  ),
                                ],
                              ),
                            ),
                            onSelected: (value) {
                              widget.controller.setShader(value.index);
                              if (context.mounted) {
                                (context as Element).markNeedsBuild();
                              }
                            },
                            itemBuilder:
                                (context) =>
                                    SuperResolutionType.values
                                        .map(
                                          (item) => PopupMenuItem(
                                            value: item,
                                            child: Text(item.title),
                                          ),
                                        )
                                        .toList(),
                          ),
                    ),
                  ],
                ),
              ),
              ListTile(
                dense: true,
                title: const Text('CDN 设置', style: titleStyle),
                leading: const Icon(MdiIcons.cloudPlusOutline, size: 20),
                subtitle: Text(
                  '当前：${CDNService.fromCode(VideoUtils.cdnService).desc}，无法播放请切换',
                  style: subTitleStyle,
                ),
                onTap: () async {
                  Get.back();
                  String? result = await showDialog(
                    context: context,
                    builder: (context) {
                      return CdnSelectDialog(
                        sample: videoInfo.dash?.video?.first,
                      );
                    },
                  );
                  if (result != null) {
                    VideoUtils.cdnService = result;
                    setting.put(SettingBoxKey.CDNService, result);
                    SmartDialog.showToast(
                      '已设置为 ${CDNService.fromCode(result).desc}，正在重载视频',
                    );
                    setState(() {});
                    videoDetailCtr.queryVideoUrl(videoDetailCtr.playedTime);
                  }
                },
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  spacing: 10,
                  children: [
                    Obx(() {
                      final flipX = widget.controller.flipX.value;
                      return ActionRowLineItem(
                        iconData: Icons.flip,
                        onTap: () => widget.controller.flipX.value = !flipX,
                        text: " 左右翻转 ",
                        selectStatus: flipX,
                      );
                    }),
                    Obx(() {
                      final flipY = widget.controller.flipY.value;
                      return ActionRowLineItem(
                        icon: Transform.rotate(
                          angle: pi / 2,
                          child: Icon(
                            Icons.flip,
                            size: 13,
                            color:
                                flipY
                                    ? theme.colorScheme.onSecondaryContainer
                                    : theme.colorScheme.outline,
                          ),
                        ),
                        onTap: () {
                          widget.controller.flipY.value = !flipY;
                        },
                        text: " 上下翻转 ",
                        selectStatus: flipY,
                      );
                    }),
                    Obx(() {
                      final onlyPlayAudio =
                          widget.controller.onlyPlayAudio.value;
                      return ActionRowLineItem(
                        iconData: Icons.headphones,
                        onTap: () {
                          widget.controller.onlyPlayAudio.value =
                              !onlyPlayAudio;
                          widget.videoDetailCtr.playerInit();
                        },
                        text: " 听视频 ",
                        selectStatus: onlyPlayAudio,
                      );
                    }),
                    Obx(
                      () => ActionRowLineItem(
                        iconData: Icons.play_circle_outline,
                        onTap: widget.controller.setContinuePlayInBackground,
                        text: " 后台播放 ",
                        selectStatus:
                            widget.controller.continuePlayInBackground.value,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                dense: true,
                onTap: () {
                  Get.back();
                  showSetVideoQa();
                },
                leading: const Icon(Icons.play_circle_outline, size: 20),
                title: const Text('选择画质', style: titleStyle),
                subtitle: Text(
                  '当前画质 ${videoDetailCtr.currentVideoQa.desc}',
                  style: subTitleStyle,
                ),
              ),
              if (videoDetailCtr.currentAudioQa != null)
                ListTile(
                  dense: true,
                  onTap: () {
                    Get.back();
                    showSetAudioQa();
                  },
                  leading: const Icon(Icons.album_outlined, size: 20),
                  title: const Text('选择音质', style: titleStyle),
                  subtitle: Text(
                    '当前音质 ${videoDetailCtr.currentAudioQa!.desc}',
                    style: subTitleStyle,
                  ),
                ),
              ListTile(
                dense: true,
                onTap: () {
                  Get.back();
                  showSetDecodeFormats();
                },
                leading: const Icon(Icons.av_timer_outlined, size: 20),
                title: const Text('解码格式', style: titleStyle),
                subtitle: Text(
                  '当前解码格式 ${videoDetailCtr.currentDecodeFormats.description}',
                  style: subTitleStyle,
                ),
              ),
              ListTile(
                dense: true,
                onTap: () {
                  Get.back();
                  showSetRepeat();
                },
                leading: const Icon(Icons.repeat, size: 20),
                title: const Text('播放顺序', style: titleStyle),
                subtitle: Text(
                  widget.controller.playRepeat.desc,
                  style: subTitleStyle,
                ),
              ),
              ListTile(
                dense: true,
                onTap: () {
                  Get.back();
                  showSetDanmaku();
                },
                leading: const Icon(CustomIcon.dm_settings, size: 20),
                title: const Text('弹幕设置', style: titleStyle),
              ),
              ListTile(
                dense: true,
                onTap: () {
                  Get.back();
                  showSetSubtitle();
                },
                leading: const Icon(Icons.subtitles_outlined, size: 20),
                title: const Text('字幕设置', style: titleStyle),
              ),
              if (videoDetailCtr.subtitles.isNotEmpty)
                ListTile(
                  dense: true,
                  onTap: () {
                    Get.back();
                    onExportSubtitle();
                  },
                  leading: const Icon(Icons.download_outlined, size: 20),
                  title: const Text('保存字幕', style: titleStyle),
                ),
              ListTile(
                dense: true,
                title: const Text('播放信息', style: titleStyle),
                leading: const Icon(Icons.info_outline, size: 20),
                onTap: () {
                  Player? player = widget.controller.videoPlayerController;
                  if (player == null) {
                    SmartDialog.showToast('播放器未初始化');
                    return;
                  }
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('播放信息'),
                        content: SingleChildScrollView(
                          child: Column(
                            children: [
                              ListTile(
                                dense: true,
                                title: const Text("Resolution"),
                                subtitle: Text(
                                  '${player.state.width}x${player.state.height}',
                                ),
                                onTap:
                                    () => Utils.copyText(
                                      'Resolution\n${player.state.width}x${player.state.height}',
                                      needToast: false,
                                    ),
                              ),
                              ListTile(
                                dense: true,
                                title: const Text("VideoParams"),
                                subtitle: Text(
                                  player.state.videoParams.toString(),
                                ),
                                onTap:
                                    () => Utils.copyText(
                                      'VideoParams\n${player.state.videoParams}',
                                      needToast: false,
                                    ),
                              ),
                              ListTile(
                                dense: true,
                                title: const Text("AudioParams"),
                                subtitle: Text(
                                  player.state.audioParams.toString(),
                                ),
                                onTap:
                                    () => Utils.copyText(
                                      'AudioParams\n${player.state.audioParams}',
                                      needToast: false,
                                    ),
                              ),
                              ListTile(
                                dense: true,
                                title: const Text("Media"),
                                subtitle: Text(
                                  player.state.playlist.toString(),
                                ),
                                onTap:
                                    () => Utils.copyText(
                                      'Media\n${player.state.playlist}',
                                      needToast: false,
                                    ),
                              ),
                              ListTile(
                                dense: true,
                                title: const Text("AudioTrack"),
                                subtitle: Text(
                                  player.state.track.audio.toString(),
                                ),
                                onTap:
                                    () => Utils.copyText(
                                      'AudioTrack\n${player.state.track.audio}',
                                      needToast: false,
                                    ),
                              ),
                              ListTile(
                                dense: true,
                                title: const Text("VideoTrack"),
                                subtitle: Text(
                                  player.state.track.video.toString(),
                                ),
                                onTap:
                                    () => Utils.copyText(
                                      'VideoTrack\n${player.state.track.audio}',
                                      needToast: false,
                                    ),
                              ),
                              ListTile(
                                dense: true,
                                title: const Text("pitch"),
                                subtitle: Text(player.state.pitch.toString()),
                                onTap:
                                    () => Utils.copyText(
                                      'pitch\n${player.state.pitch}',
                                      needToast: false,
                                    ),
                              ),
                              ListTile(
                                dense: true,
                                title: const Text("rate"),
                                subtitle: Text(player.state.rate.toString()),
                                onTap:
                                    () => Utils.copyText(
                                      'rate\n${player.state.rate}',
                                      needToast: false,
                                    ),
                              ),
                              ListTile(
                                dense: true,
                                title: const Text("AudioBitrate"),
                                subtitle: Text(
                                  player.state.audioBitrate.toString(),
                                ),
                                onTap:
                                    () => Utils.copyText(
                                      'AudioBitrate\n${player.state.audioBitrate}',
                                      needToast: false,
                                    ),
                              ),
                              ListTile(
                                dense: true,
                                title: const Text("Volume"),
                                subtitle: Text(player.state.volume.toString()),
                                onTap:
                                    () => Utils.copyText(
                                      'Volume\n${player.state.volume}',
                                      needToast: false,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: Get.back,
                            child: Text(
                              '确定',
                              style: TextStyle(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              ListTile(
                dense: true,
                onTap: () {
                  if (!Accounts.main.isLogin) {
                    SmartDialog.showToast('账号未登录');
                    return;
                  }
                  Get.back();
                  PageUtils.reportVideo(videoDetailCtr.aid);
                },
                leading: const Icon(Icons.error_outline, size: 20),
                title: const Text('举报', style: titleStyle),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showPlayFromLinkDialog() {
    final TextEditingController urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('从链接播放'),
          content: TextField(
            controller: urlController,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: '请输入视频链接，如 https://...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            minLines: 1,
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text(
                '取消',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () async {
                final String url = urlController.text.trim();
                if (url.isEmpty) {
                  SmartDialog.showToast('请输入有效链接');
                  return;
                }
                Get.back();
                try {
                  SmartDialog.showToast('正在从链接播放');
                  await videoDetailCtr.playerInit(
                    video: url,
                    audio: '',
                    autoplay: true,
                    seekToTime: Duration.zero,
                  );
                } catch (e) {
                  SmartDialog.showToast('播放失败：$e');
                }
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  /// 选择画质
  void showSetVideoQa() {
    if (videoInfo.dash == null) {
      SmartDialog.showToast('当前视频不支持选择画质');
      return;
    }
    final List<FormatItem> videoFormat = videoInfo.supportFormats!;
    final VideoQuality currentVideoQa = videoDetailCtr.currentVideoQa;

    /// 总质量分类
    final int totalQaSam = videoFormat.length;

    /// 可用的质量分类
    int userfulQaSam = 0;
    final List<VideoItem> video = videoInfo.dash!.video!;
    final Set<int> idSet = {};
    for (final VideoItem item in video) {
      final int id = item.id!;
      if (!idSet.contains(id)) {
        idSet.add(id);
        userfulQaSam++;
      }
    }

    showBottomSheet((context, setState) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          clipBehavior: Clip.hardEdge,
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 45,
                child: GestureDetector(
                  onTap:
                      () => SmartDialog.showToast(
                        '标灰画质需要bilibili会员（已是会员？请关闭无痕模式）；4k和杜比视界播放效果可能不佳',
                      ),
                  child: Row(
                    spacing: 8,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('选择画质', style: titleStyle),
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                    ],
                  ),
                ),
              ),
              ...List.generate(totalQaSam, (index) {
                final item = videoFormat[index];
                return ListTile(
                  dense: true,
                  onTap: () async {
                    if (currentVideoQa.code == item.quality) {
                      return;
                    }
                    Get.back();
                    final int quality = item.quality!;
                    videoDetailCtr
                      ..currentVideoQa = VideoQuality.fromCode(quality)
                      ..updatePlayer();

                    // update
                    if (!plPlayerController.tempPlayerConf) {
                      final res = await Connectivity().checkConnectivity();
                      if (res.contains(ConnectivityResult.wifi)) {
                        setting.put(SettingBoxKey.defaultVideoQa, quality);
                      } else {
                        setting.put(
                          SettingBoxKey.defaultVideoQaCellular,
                          quality,
                        );
                      }
                    }
                    SmartDialog.showToast(
                      "画质已变为：${VideoQuality.fromCode(quality).desc}",
                    );
                  },
                  // 可能包含会员解锁画质
                  enabled: index >= totalQaSam - userfulQaSam,
                  contentPadding: const EdgeInsets.only(left: 20, right: 20),
                  title: Text(item.newDesc!),
                  trailing:
                      currentVideoQa.code == item.quality
                          ? Icon(Icons.done, color: theme.colorScheme.primary)
                          : Text(item.format!, style: subTitleStyle),
                );
              }),
            ],
          ),
        ),
      );
    });
  }

  /// 选择音质
  void showSetAudioQa() {
    final AudioQuality currentAudioQa = videoDetailCtr.currentAudioQa!;
    final List<AudioItem> audio = videoInfo.dash!.audio!;
    showBottomSheet((context, setState) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          clipBehavior: Clip.hardEdge,
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(
                height: 45,
                child: Center(child: Text('选择音质', style: titleStyle)),
              ),
              for (final AudioItem i in audio) ...[
                ListTile(
                  dense: true,
                  onTap: () async {
                    if (currentAudioQa.code == i.id) {
                      return;
                    }
                    Get.back();
                    final int quality = i.id!;
                    videoDetailCtr
                      ..currentAudioQa = AudioQuality.fromCode(quality)
                      ..updatePlayer();

                    // update
                    if (!plPlayerController.tempPlayerConf) {
                      final res = await Connectivity().checkConnectivity();
                      if (res.contains(ConnectivityResult.wifi)) {
                        setting.put(SettingBoxKey.defaultAudioQa, quality);
                      } else {
                        setting.put(
                          SettingBoxKey.defaultAudioQaCellular,
                          quality,
                        );
                      }
                    }
                    SmartDialog.showToast(
                      "音质已变为：${AudioQuality.fromCode(quality).desc}",
                    );
                  },
                  contentPadding: const EdgeInsets.only(left: 20, right: 20),
                  title: Text(i.quality),
                  subtitle: Text(i.codecs!, style: subTitleStyle),
                  trailing:
                      currentAudioQa.code == i.id
                          ? Icon(Icons.done, color: theme.colorScheme.primary)
                          : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  // 选择解码格式
  void showSetDecodeFormats() {
    // 当前选中的解码格式
    final VideoDecodeFormatType currentDecodeFormats =
        videoDetailCtr.currentDecodeFormats;
    final VideoItem firstVideo = videoDetailCtr.firstVideo;
    // 当前视频可用的解码格式
    final List<FormatItem> videoFormat = videoInfo.supportFormats!;
    final List<String>? list =
        videoFormat
            .firstWhere((FormatItem e) => e.quality == firstVideo.quality.code)
            .codecs;
    if (list == null) {
      SmartDialog.showToast('当前视频不支持选择解码格式');
      return;
    }

    showBottomSheet((context, setState) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          clipBehavior: Clip.hardEdge,
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Column(
            children: [
              const SizedBox(
                height: 45,
                child: Center(child: Text('选择解码格式', style: titleStyle)),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (var i in list) ...[
                      ListTile(
                        dense: true,
                        onTap: () {
                          if (i.startsWith(currentDecodeFormats.code)) {
                            return;
                          }
                          videoDetailCtr
                            ..currentDecodeFormats =
                                VideoDecodeFormatTypeExt.fromString(i)!
                            ..updatePlayer();
                          Get.back();
                        },
                        contentPadding: const EdgeInsets.only(
                          left: 20,
                          right: 20,
                        ),
                        title: Text(
                          VideoDecodeFormatTypeExt.fromString(i)!.description,
                        ),
                        subtitle: Text(i, style: subTitleStyle),
                        trailing:
                            i.startsWith(currentDecodeFormats.code)
                                ? Icon(
                                  Icons.done,
                                  color: theme.colorScheme.primary,
                                )
                                : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void onExportSubtitle() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          clipBehavior: Clip.hardEdge,
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
          title: const Text('保存字幕'),
          content: SingleChildScrollView(
            child: Column(
              children:
                  videoDetailCtr.subtitles
                      .map(
                        (item) => ListTile(
                          dense: true,
                          onTap: () async {
                            Get.back();
                            try {
                              final res = await Dio().get(
                                item.subtitleUrl!.http2https,
                                options: Options(
                                  responseType: ResponseType.bytes,
                                ),
                              );
                              if (res.statusCode == 200) {
                                final name =
                                    '${introController.videoDetail.value.title}-${videoDetailCtr.bvid}-${videoDetailCtr.cid.value}-${item.lanDoc}.json';
                                try {
                                  DocumentFileSavePlusPlatform.instance
                                      .saveMultipleFiles(
                                        dataList: [res.data],
                                        fileNameList: [name],
                                        mimeTypeList: [Headers.jsonContentType],
                                      );
                                  if (Platform.isAndroid) {
                                    SmartDialog.showToast('已保存');
                                  }
                                } catch (e) {
                                  SharePlus.instance.share(
                                    ShareParams(
                                      files: [
                                        XFile.fromData(
                                          res.data,
                                          name: name,
                                          mimeType: Headers.jsonContentType,
                                        ),
                                      ],
                                      sharePositionOrigin:
                                          await Utils.sharePositionOrigin,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              SmartDialog.showToast(e.toString());
                            }
                          },
                          title: Text(
                            item.lanDoc!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        );
      },
    );
  }

  /// 字幕设置
  void showSetSubtitle() {
    double subtitleFontScale = widget.controller.subtitleFontScale;
    double subtitleFontScaleFS = widget.controller.subtitleFontScaleFS;
    int subtitlePaddingH = widget.controller.subtitlePaddingH;
    int subtitlePaddingB = widget.controller.subtitlePaddingB;
    double subtitleBgOpaticy = widget.controller.subtitleBgOpaticy;
    double subtitleStrokeWidth = widget.controller.subtitleStrokeWidth;
    int subtitleFontWeight = widget.controller.subtitleFontWeight;

    showBottomSheet(padding: isFullScreen ? 70 : null, (context, setState) {
      final theme = Theme.of(context);

      final sliderTheme = SliderThemeData(
        trackHeight: 10,
        trackShape: const MSliderTrackShape(),
        thumbColor: theme.colorScheme.primary,
        activeTrackColor: theme.colorScheme.primary,
        inactiveTrackColor: theme.colorScheme.onInverseSurface,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
      );

      void updateStrokeWidth(double val) {
        subtitleStrokeWidth = val;
        widget.controller
          ..subtitleStrokeWidth = subtitleStrokeWidth
          ..updateSubtitleStyle()
          ..putSubtitleSettings();
        setState(() {});
      }

      void updateOpacity(double val) {
        subtitleBgOpaticy = val;
        widget.controller
          ..subtitleBgOpaticy = subtitleBgOpaticy
          ..updateSubtitleStyle()
          ..putSubtitleSettings();
        setState(() {});
      }

      void updateBottomPadding(int val) {
        subtitlePaddingB = val;
        widget.controller
          ..subtitlePaddingB = subtitlePaddingB
          ..updateSubtitleStyle()
          ..putSubtitleSettings();
        setState(() {});
      }

      void updateHorizontalPadding(int val) {
        subtitlePaddingH = val;
        widget.controller
          ..subtitlePaddingH = subtitlePaddingH
          ..updateSubtitleStyle()
          ..putSubtitleSettings();
        setState(() {});
      }

      void updateFontScaleFS(double val) {
        subtitleFontScaleFS = val;
        widget.controller
          ..subtitleFontScaleFS = subtitleFontScaleFS
          ..updateSubtitleStyle()
          ..putSubtitleSettings();
        setState(() {});
      }

      void updateFontScale(double val) {
        subtitleFontScale = val;
        widget.controller
          ..subtitleFontScale = subtitleFontScale
          ..updateSubtitleStyle()
          ..putSubtitleSettings();
        setState(() {});
      }

      void updateFontWeight(int val) {
        subtitleFontWeight = val;
        widget.controller
          ..subtitleFontWeight = subtitleFontWeight
          ..updateSubtitleStyle()
          ..putSubtitleSettings();
        setState(() {});
      }

      return Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          clipBehavior: Clip.hardEdge,
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(
                  height: 45,
                  child: Center(child: Text('字幕设置', style: titleStyle)),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '字体大小 ${(subtitleFontScale * 100).toStringAsFixed(1)}%',
                    ),
                    resetBtn(theme, '100.0%', () => updateFontScale(1.0)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0.5,
                      max: 2.5,
                      value: subtitleFontScale,
                      divisions: 20,
                      label: '${(subtitleFontScale * 100).toStringAsFixed(1)}%',
                      onChanged: updateFontScale,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '全屏字体大小 ${(subtitleFontScaleFS * 100).toStringAsFixed(1)}%',
                    ),
                    resetBtn(theme, '150.0%', () => updateFontScaleFS(1.5)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0.5,
                      max: 2.5,
                      value: subtitleFontScaleFS,
                      divisions: 20,
                      label:
                          '${(subtitleFontScaleFS * 100).toStringAsFixed(1)}%',
                      onChanged: updateFontScaleFS,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('字体粗细 ${subtitleFontWeight + 1}（可能无法精确调节）'),
                    resetBtn(theme, 6, () => updateFontWeight(5)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0,
                      max: 8,
                      value: subtitleFontWeight.toDouble(),
                      divisions: 8,
                      label: '${subtitleFontWeight + 1}',
                      onChanged: (double val) {
                        updateFontWeight(val.toInt());
                      },
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('描边粗细 $subtitleStrokeWidth'),
                    resetBtn(theme, 2.0, () => updateStrokeWidth(2.0)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0,
                      max: 5,
                      value: subtitleStrokeWidth,
                      divisions: 10,
                      label: '$subtitleStrokeWidth',
                      onChanged: updateStrokeWidth,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('左右边距 $subtitlePaddingH'),
                    resetBtn(theme, 24, () => updateHorizontalPadding(24)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0,
                      max: 100,
                      value: subtitlePaddingH.toDouble(),
                      divisions: 100,
                      label: '$subtitlePaddingH',
                      onChanged: (double val) {
                        updateHorizontalPadding(val.round());
                      },
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('底部边距 $subtitlePaddingB'),
                    resetBtn(theme, 24, () => updateBottomPadding(24)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0,
                      max: 200,
                      value: subtitlePaddingB.toDouble(),
                      divisions: 200,
                      label: '$subtitlePaddingB',
                      onChanged: (double val) {
                        updateBottomPadding(val.round());
                      },
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('背景不透明度 ${(subtitleBgOpaticy * 100).toInt()}%'),
                    resetBtn(theme, '67%', () => updateOpacity(0.67)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0,
                      max: 1,
                      value: subtitleBgOpaticy,
                      onChanged: (double val) {
                        updateOpacity(val.toPrecision(2));
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget resetBtn(ThemeData theme, Object def, VoidCallback onPressed) {
    return iconButton(
      context: context,
      tooltip: '默认值: $def',
      icon: Icons.refresh,
      onPressed: onPressed,
      bgColor: Colors.transparent,
      iconColor: theme.colorScheme.outline,
      size: 24,
      iconSize: 24,
    );
  }

  /// 弹幕功能
  void showSetDanmaku() {
    // 屏蔽类型
    const List<({int value, String label})> blockTypesList = [
      (value: 5, label: '顶部'),
      (value: 2, label: '滚动'),
      (value: 4, label: '底部'),
      (value: 6, label: '彩色'),
    ];
    final blockTypes = widget.controller.blockTypes;
    // 智能云屏蔽
    int danmakuWeight = widget.controller.danmakuWeight;
    // 显示区域
    double showArea = widget.controller.showArea;
    // 不透明度
    double opacity = widget.controller.danmakuOpacity;
    // 字体大小
    double fontSize = widget.controller.danmakuFontScale;
    // 全屏字体大小
    double fontSizeFS = widget.controller.danmakuFontScaleFS;
    double danmakuLineHeight = widget.controller.danmakuLineHeight;
    // 弹幕速度
    double danmakuDuration = widget.controller.danmakuDuration;
    double danmakuStaticDuration = widget.controller.danmakuStaticDuration;
    // 弹幕描边
    double strokeWidth = widget.controller.strokeWidth;
    // 字体粗细
    int fontWeight = widget.controller.fontWeight;
    bool massiveMode = widget.controller.massiveMode;

    final DanmakuController? danmakuController =
        widget.controller.danmakuController;

    showBottomSheet((context, setState) {
      final theme = Theme.of(context);

      final sliderTheme = SliderThemeData(
        trackHeight: 10,
        trackShape: const MSliderTrackShape(),
        thumbColor: theme.colorScheme.primary,
        activeTrackColor: theme.colorScheme.primary,
        inactiveTrackColor: theme.colorScheme.onInverseSurface,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
      );

      void updateLineHeight(double val) {
        danmakuLineHeight = val;
        widget.controller
          ..danmakuLineHeight = danmakuLineHeight
          ..putDanmakuSettings();
        setState(() {});
        try {
          danmakuController?.updateOption(
            danmakuController.option.copyWith(lineHeight: danmakuLineHeight),
          );
        } catch (_) {}
      }

      void updateDuration(double val) {
        danmakuDuration = val;
        widget.controller
          ..danmakuDuration = danmakuDuration
          ..putDanmakuSettings();
        setState(() {});
        try {
          danmakuController?.updateOption(
            danmakuController.option.copyWith(
              duration: danmakuDuration / widget.controller.playbackSpeed,
            ),
          );
        } catch (_) {}
      }

      void updateStaticDuration(double val) {
        danmakuStaticDuration = val;
        widget.controller
          ..danmakuStaticDuration = danmakuStaticDuration
          ..putDanmakuSettings();
        setState(() {});
        try {
          danmakuController?.updateOption(
            danmakuController.option.copyWith(
              staticDuration:
                  danmakuStaticDuration / widget.controller.playbackSpeed,
            ),
          );
        } catch (_) {}
      }

      void updateFontSizeFS(double val) {
        fontSizeFS = val;
        widget.controller
          ..danmakuFontScaleFS = fontSizeFS
          ..putDanmakuSettings();
        setState(() {});
        if (isFullScreen) {
          try {
            danmakuController?.updateOption(
              danmakuController.option.copyWith(
                fontSize: (15 * fontSizeFS).toDouble(),
              ),
            );
          } catch (_) {}
        }
      }

      void updateFontSize(double val) {
        fontSize = val;
        widget.controller
          ..danmakuFontScale = fontSize
          ..putDanmakuSettings();
        setState(() {});
        if (!isFullScreen) {
          try {
            danmakuController?.updateOption(
              danmakuController.option.copyWith(
                fontSize: (15 * fontSize).toDouble(),
              ),
            );
          } catch (_) {}
        }
      }

      void updateStrokeWidth(double val) {
        strokeWidth = val;
        widget.controller
          ..strokeWidth = val
          ..putDanmakuSettings();
        setState(() {});
        try {
          danmakuController?.updateOption(
            danmakuController.option.copyWith(strokeWidth: val),
          );
        } catch (_) {}
      }

      void updateFontWeight(int val) {
        fontWeight = val;
        widget.controller
          ..fontWeight = fontWeight
          ..putDanmakuSettings();
        setState(() {});
        try {
          danmakuController?.updateOption(
            danmakuController.option.copyWith(fontWeight: fontWeight),
          );
        } catch (_) {}
      }

      void updateOpacity(double val) {
        opacity = val;
        widget.controller
          ..danmakuOpacity = opacity
          ..putDanmakuSettings();
        setState(() {});
        try {
          danmakuController?.updateOption(
            danmakuController.option.copyWith(opacity: val),
          );
        } catch (_) {}
      }

      void updateShowArea(double val) {
        showArea = val;
        widget.controller
          ..showArea = showArea
          ..putDanmakuSettings();
        setState(() {});
        try {
          danmakuController?.updateOption(
            danmakuController.option.copyWith(area: showArea),
          );
        } catch (_) {}
      }

      return Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          clipBehavior: Clip.hardEdge,
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(
                  height: 45,
                  child: Center(child: Text('弹幕设置', style: titleStyle)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('智能云屏蔽 $danmakuWeight 级'),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed:
                          () =>
                              Get
                                ..back()
                                ..toNamed(
                                  '/danmakuBlock',
                                  arguments: widget.controller,
                                ),
                      child: Text("屏蔽管理(${plPlayerController.filters.count})"),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0,
                      max: 10,
                      value: danmakuWeight.toDouble(),
                      divisions: 10,
                      label: '$danmakuWeight',
                      onChanged: (double val) {
                        danmakuWeight = val.toInt();
                        widget.controller
                          ..danmakuWeight = danmakuWeight
                          ..putDanmakuSettings();
                        setState(() {});
                      },
                    ),
                  ),
                ),
                const Text('按类型屏蔽'),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      for (final (value: value, label: label)
                          in blockTypesList) ...[
                        ActionRowLineItem(
                          onTap: () {
                            if (blockTypes.contains(value)) {
                              blockTypes.remove(value);
                            } else {
                              blockTypes.add(value);
                            }
                            widget.controller
                              ..blockTypes = blockTypes
                              ..putDanmakuSettings();
                            setState(() {});
                            try {
                              danmakuController?.updateOption(
                                danmakuController.option.copyWith(
                                  hideTop: blockTypes.contains(5),
                                  hideBottom: blockTypes.contains(4),
                                  hideScroll: blockTypes.contains(2),
                                  // 添加或修改其他需要修改的选项属性
                                ),
                              );
                            } catch (_) {}
                          },
                          text: label,
                          selectStatus: blockTypes.contains(value),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
                SetSwitchItem(
                  title: '海量弹幕',
                  contentPadding: EdgeInsets.zero,
                  titleStyle: const TextStyle(fontSize: 14),
                  defaultVal: massiveMode,
                  setKey: SettingBoxKey.danmakuMassiveMode,
                  onChanged: (value) {
                    massiveMode = value;
                    widget.controller.massiveMode = value;
                    setState(() {});
                    try {
                      danmakuController?.updateOption(
                        danmakuController.option.copyWith(massiveMode: value),
                      );
                    } catch (_) {}
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('显示区域 ${showArea * 100}%'),
                    resetBtn(theme, '50.0%', () => updateShowArea(0.5)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0.1,
                      max: 1,
                      value: showArea,
                      divisions: 9,
                      label: '${showArea * 100}%',
                      onChanged: (val) => updateShowArea(val.toPrecision(1)),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('不透明度 ${opacity * 100}%'),
                    resetBtn(theme, '100.0%', () => updateOpacity(1.0)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0,
                      max: 1,
                      value: opacity,
                      divisions: 10,
                      label: '${opacity * 100}%',
                      onChanged: updateOpacity,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('字体粗细 ${fontWeight + 1}（可能无法精确调节）'),
                    resetBtn(theme, 6, () => updateFontWeight(5)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0,
                      max: 8,
                      value: fontWeight.toDouble(),
                      divisions: 8,
                      label: '${fontWeight + 1}',
                      onChanged: (double val) {
                        updateFontWeight(val.toInt());
                      },
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('描边粗细 $strokeWidth'),
                    resetBtn(theme, 1.5, () => updateStrokeWidth(1.5)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0,
                      max: 3,
                      value: strokeWidth,
                      divisions: 6,
                      label: '$strokeWidth',
                      onChanged: updateStrokeWidth,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('字体大小 ${(fontSize * 100).toStringAsFixed(1)}%'),
                    resetBtn(theme, '100.0%', () => updateFontSize(1.0)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0.5,
                      max: 2.5,
                      value: fontSize,
                      divisions: 20,
                      label: '${(fontSize * 100).toStringAsFixed(1)}%',
                      onChanged: updateFontSize,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('全屏字体大小 ${(fontSizeFS * 100).toStringAsFixed(1)}%'),
                    resetBtn(theme, '120.0%', () => updateFontSizeFS(1.2)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 0.5,
                      max: 2.5,
                      value: fontSizeFS,
                      divisions: 20,
                      label: '${(fontSizeFS * 100).toStringAsFixed(1)}%',
                      onChanged: updateFontSizeFS,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('滚动弹幕时长 $danmakuDuration 秒'),
                    resetBtn(theme, 7.0, () => updateDuration(7.0)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 1,
                      max: 50,
                      value: danmakuDuration,
                      divisions: 49,
                      label: danmakuDuration.toString(),
                      onChanged: (double val) {
                        updateDuration(val.toPrecision(1));
                      },
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('静态弹幕时长 $danmakuStaticDuration 秒'),
                    resetBtn(theme, 4.0, () => updateStaticDuration(4.0)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 1,
                      max: 50,
                      value: danmakuStaticDuration,
                      divisions: 49,
                      label: danmakuStaticDuration.toString(),
                      onChanged: (double val) {
                        updateStaticDuration(val.toPrecision(1));
                      },
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('弹幕行高 $danmakuLineHeight'),
                    resetBtn(theme, 1.6, () => updateLineHeight(1.6)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 6,
                    left: 10,
                    right: 10,
                  ),
                  child: SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 1.0,
                      max: 3.0,
                      value: danmakuLineHeight,
                      onChanged: (double val) {
                        updateLineHeight(val.toPrecision(1));
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// 播放顺序
  void showSetRepeat() {
    showBottomSheet((context, setState) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          clipBehavior: Clip.hardEdge,
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(
                height: 45,
                child: Center(child: Text('选择播放顺序', style: titleStyle)),
              ),
              for (final PlayRepeat i in PlayRepeat.values) ...[
                ListTile(
                  dense: true,
                  onTap: () {
                    widget.controller.setPlayRepeat(i);
                    Get.back();
                  },
                  contentPadding: const EdgeInsets.only(left: 20, right: 20),
                  title: Text(i.desc),
                  trailing:
                      widget.controller.playRepeat == i
                          ? Icon(Icons.done, color: theme.colorScheme.primary)
                          : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  static final _format = DateFormat('HH:mm');

  void startClock() {
    clock ??= Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        clock?.cancel();
        return;
      }
      now.value = _format.format(DateTime.now());
    });
  }

  Widget _buildHeader(bool showFSActionItem) => AppBar(
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    primary: false,
    automaticallyImplyLeading: false,
    toolbarHeight: showFSActionItem && isFullScreen ? 112 : null,
    flexibleSpace: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 11),
        Row(
          children: [
            SizedBox(
              width: 42,
              height: 34,
              child: IconButton(
                tooltip: '返回',
                icon: const Icon(
                  FontAwesomeIcons.arrowLeft,
                  size: 15,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (isFullScreen) {
                    widget.controller.triggerFullScreen(status: false);
                  } else if (!horizontalScreen && !isPortrait) {
                    verticalScreenForTwoSeconds();
                  } else {
                    Get.back();
                  }
                },
              ),
            ),
            if (!isFullScreen || !isPortrait)
              SizedBox(
                width: 42,
                height: 34,
                child: IconButton(
                  tooltip: '返回主页',
                  icon: const Icon(
                    FontAwesomeIcons.house,
                    size: 15,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    videoDetailCtr.plPlayerController.backToHome = true;
                    Get.until((route) => route.isFirst);
                  },
                ),
              ),
            if ((introController.videoDetail.value.title != null) &&
                (isFullScreen || (!horizontalScreen && !isPortrait)))
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Obx(() {
                          String title;
                          final videoDetail = introController.videoDetail.value;
                          if (videoDetail.videos == 1) {
                            title = videoDetail.title!;
                          } else {
                            title =
                                videoDetail.pages
                                    ?.firstWhereOrNull(
                                      (e) => e.cid == videoDetailCtr.cid.value,
                                    )
                                    ?.pagePart ??
                                videoDetail.title!;
                          }
                          final textPainter = TextPainter(
                            text: TextSpan(
                              text: title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            textDirection: TextDirection.ltr,
                            maxLines: 1,
                          )..layout(maxWidth: constraints.maxWidth);
                          if (textPainter.didExceedMaxLines) {
                            return ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 25),
                              child: Marquee(
                                text: title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                scrollAxis: Axis.horizontal,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                blankSpace: 200,
                                velocity: 40,
                                startAfter: const Duration(seconds: 1),
                                showFadingOnlyWhenScrolling: true,
                                fadingEdgeStartFraction: 0,
                                fadingEdgeEndFraction: 0.1,
                                numberOfRounds: 1,
                                startPadding: 0,
                                accelerationDuration: const Duration(
                                  seconds: 1,
                                ),
                                accelerationCurve: Curves.linear,
                                decelerationDuration: const Duration(
                                  milliseconds: 500,
                                ),
                                decelerationCurve: Curves.easeOut,
                              ),
                            );
                          } else {
                            return Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              textDirection: TextDirection.ltr,
                            );
                          }
                        });
                      },
                    ),
                    if (introController.isShowOnlineTotal)
                      Obx(
                        () => Text(
                          '${introController.total.value}人正在看',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              const Spacer(),
            // show current datetime
            Obx(() {
              if ((isFullScreen || !horizontalScreen) && !isPortrait) {
                startClock();
                return Text(
                  now.value,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                );
              }
              clock?.cancel();
              clock = null;
              return const SizedBox.shrink();
            }),
            if (plPlayerController.enableSponsorBlock == true)
              SizedBox(
                width: 42,
                height: 34,
                child: IconButton(
                  tooltip: '提交片段',
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () => videoDetailCtr.onBlock(context),
                  icon: const Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 19,
                        color: Colors.white,
                      ),
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            Obx(
              () =>
                  videoDetailCtr.segmentList.isNotEmpty
                      ? SizedBox(
                        width: 42,
                        height: 34,
                        child: IconButton(
                          tooltip: '片段信息',
                          style: ButtonStyle(
                            padding: WidgetStateProperty.all(EdgeInsets.zero),
                          ),
                          onPressed: () => videoDetailCtr.showSBDetail(context),
                          icon: const Icon(
                            MdiIcons.advertisements,
                            size: 19,
                            color: Colors.white,
                          ),
                        ),
                      )
                      : const SizedBox.shrink(),
            ),
            SizedBox(
              width: 42,
              height: 34,
              child: IconButton(
                tooltip: '发弹幕',
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                ),
                onPressed: videoDetailCtr.showShootDanmakuSheet,
                icon: const Icon(
                  Icons.comment_outlined,
                  size: 19,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(
              width: 42,
              height: 34,
              child: Obx(() {
                final enableShowDanmaku =
                    plPlayerController.enableShowDanmaku.value;
                return IconButton(
                  tooltip: "${enableShowDanmaku ? '关闭' : '开启'}弹幕",
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () {
                    final newVal = !enableShowDanmaku;
                    plPlayerController.enableShowDanmaku.value = newVal;
                    if (!plPlayerController.tempPlayerConf) {
                      setting.put(SettingBoxKey.enableShowDanmaku, newVal);
                    }
                  },
                  icon: Icon(
                    enableShowDanmaku
                        ? Icons.subtitles_outlined
                        : Icons.subtitles_off_outlined,
                    size: 19,
                    color: Colors.white,
                  ),
                );
              }),
            ),
            if (Platform.isAndroid)
              SizedBox(
                width: 42,
                height: 34,
                child: IconButton(
                  tooltip: '画中画',
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () async {
                    bool canUsePiP = await Floating().isPipAvailable;
                    widget.controller.hiddenControls(false);
                    if (canUsePiP) {
                      if (!videoPlayerServiceHandler.enableBackgroundPlay &&
                          mounted) {
                        final theme = Theme.of(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Column(
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.check, color: Colors.green),
                                    SizedBox(width: 10),
                                    Text(
                                      '画中画',
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  '建议开启【后台音频服务】\n'
                                  '避免画中画没有暂停按钮',
                                  style: TextStyle(fontSize: 12.5, height: 1.5),
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      style: ButtonStyle(
                                        foregroundColor: WidgetStatePropertyAll(
                                          theme.snackBarTheme.actionTextColor,
                                        ),
                                      ),
                                      onPressed: () {
                                        plPlayerController.setBackgroundPlay(
                                          true,
                                        );
                                        SmartDialog.showToast("请重新载入本页面刷新");
                                      },
                                      child: const Text('启用后台音频服务'),
                                    ),
                                    const SizedBox(width: 10),
                                    TextButton(
                                      style: ButtonStyle(
                                        foregroundColor: WidgetStatePropertyAll(
                                          theme.snackBarTheme.actionTextColor,
                                        ),
                                      ),
                                      onPressed: () {},
                                      child: const Text('不启用'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            duration: const Duration(seconds: 2),
                            showCloseIcon: true,
                          ),
                        );
                        await Future.delayed(const Duration(seconds: 3));
                      }
                      if (!context.mounted) return;
                      PageUtils.enterPip(
                        width: widget.videoDetailCtr.firstVideo.width,
                        height: widget.videoDetailCtr.firstVideo.height,
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.picture_in_picture_outlined,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
              ),
            SizedBox(
              width: 42,
              height: 34,
              child: IconButton(
                tooltip: "更多设置",
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                ),
                onPressed: showSettingSheet,
                icon: const Icon(
                  Icons.more_vert_outlined,
                  size: 19,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        if (showFSActionItem && isFullScreen)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 42,
                height: 34,
                child: Obx(
                  () => ActionItem(
                    expand: false,
                    icon: const Icon(
                      FontAwesomeIcons.thumbsUp,
                      color: Colors.white,
                    ),
                    selectIcon: const Icon(FontAwesomeIcons.solidThumbsUp),
                    selectStatus: introController.hasLike.value,
                    semanticsLabel: '点赞',
                    animation: tripleAnimation,
                    onStartTriple: () {
                      plPlayerController.tripling = true;
                      onStartTriple();
                    },
                    onCancelTriple: ([bool isTap = false]) {
                      plPlayerController
                        ..tripling = false
                        ..hideTaskControls();
                      onCancelTriple(isTap);
                    },
                  ),
                ),
              ),
              if (introController case UgcIntroController ugc)
                SizedBox(
                  width: 42,
                  height: 34,
                  child: Obx(
                    () => ActionItem(
                      expand: false,
                      icon: const Icon(
                        FontAwesomeIcons.thumbsDown,
                        color: Colors.white,
                      ),
                      selectIcon: const Icon(FontAwesomeIcons.solidThumbsDown),
                      onTap: () => ugc.handleAction(ugc.actionDislikeVideo),
                      selectStatus: ugc.hasDislike.value,
                      semanticsLabel: '点踩',
                    ),
                  ),
                ),
              SizedBox(
                width: 42,
                height: 34,
                child: Obx(
                  () => ActionItem(
                    expand: false,
                    animation: tripleAnimation,
                    icon: const Icon(FontAwesomeIcons.b, color: Colors.white),
                    selectIcon: const Icon(FontAwesomeIcons.b),
                    onTap: introController.actionCoinVideo,
                    selectStatus: introController.hasCoin,
                    semanticsLabel: '投币',
                  ),
                ),
              ),
              SizedBox(
                width: 42,
                height: 34,
                child: Obx(
                  () => ActionItem(
                    expand: false,
                    animation: tripleAnimation,
                    icon: const Icon(
                      FontAwesomeIcons.star,
                      color: Colors.white,
                    ),
                    selectIcon: const Icon(FontAwesomeIcons.solidStar),
                    onTap: () => introController.showFavBottomSheet(context),
                    onLongPress:
                        () => introController.showFavBottomSheet(
                          context,
                          isLongPress: true,
                        ),
                    selectStatus: introController.hasFav.value,
                    semanticsLabel: '收藏',
                  ),
                ),
              ),
              SizedBox(
                width: 42,
                height: 34,
                child: ActionItem(
                  expand: false,
                  icon: const Icon(
                    FontAwesomeIcons.shareFromSquare,
                    color: Colors.white,
                  ),
                  onTap: () => introController.actionShareVideo(context),
                  semanticsLabel: '分享',
                ),
              ),
            ],
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return plPlayerController.showFSActionItem
        ? Obx(() => _buildHeader(true))
        : _buildHeader(false);
  }
}

class MSliderTrackShape extends RoundedRectSliderTrackShape {
  const MSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    SliderThemeData? sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    const double trackHeight = 3;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2 + 4;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

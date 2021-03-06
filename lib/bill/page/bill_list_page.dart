import 'dart:async';
import 'package:bookkeeping/bill/model/bill_record_group.dart';
import 'package:bookkeeping/bill/model/bill_record_response.dart';
import 'package:bookkeeping/bill/page/bookkeeping_page.dart';
import 'package:bookkeeping/common/app_def/images.dart';
import 'package:bookkeeping/common/app_def/strings.dart';
import 'package:bookkeeping/common/eventBus.dart';
import 'package:bookkeeping/db/db_helper.dart';
import 'package:bookkeeping/common/app_def//colours.dart';
import 'package:bookkeeping/common/app_def//styles.dart';
import 'package:bookkeeping/routers/fluro_navigator.dart';
import 'package:bookkeeping/common/util/utils.dart';
import 'package:bookkeeping/widgets/app_bar.dart';
import 'package:bookkeeping/widgets/calendar_page.dart';
import 'package:bookkeeping/widgets/highlight_well.dart';
import 'package:bookkeeping/widgets/state_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class BillListPage extends StatefulWidget {
  @override
  _BillState createState() => _BillState();
}

class _BillState extends State<BillListPage> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  //保存状态
  bool get wantKeepAlive => true;

  ScrollController _controller = ScrollController();

  bool _isShowToTopBtn = false;

  BillRecordMonth _monthModel = BillRecordMonth(0, 0, []);

  String _year = "${DateTime.now().year}";
  String _month = "${DateTime.now().month.toString().padLeft(2, '0')}";

  Future<void> _getCurrentMonthData() async {
    // 时间戳
    int startTime = DateTime(int.parse(_year), int.parse(_month), 1, 0, 0, 0, 0).millisecondsSinceEpoch;
    int endTime = DateTime(
            int.parse(_year), int.parse(_month), Utils.getDaysNum(int.parse(_year), int.parse(_month)), 23, 59, 59, 999)
        .millisecondsSinceEpoch;

    dbHelp.getBillRecordMonth(startTime, endTime).then((monthModel) {
      setState(() {
        _monthModel = monthModel;
      });
    });
  }

  @override
  void initState() {
    super.initState();

    _getCurrentMonthData();

    bus.add(bus.bookkeepingEventName, (arg) {
      _getCurrentMonthData();
    });

    _controller.addListener(() {
      if (_controller.offset < 200 && _isShowToTopBtn) {
        setState(() {
          _isShowToTopBtn = false;
        });
      } else if (_controller.offset >= 200 && _isShowToTopBtn == false) {
        setState(() {
          _isShowToTopBtn = true;
        });
      }
    });
  }

  double maxOffset = 150;
  double opacityValue = 0;

  void _onScroll(offset) {
    double alpha = offset / maxOffset;
    if (alpha < 0) {
      alpha = 0;
    } else if (alpha > 1) {
      alpha = 1;
    }
    setState(() {
      opacityValue = alpha;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ScreenUtil.instance = ScreenUtil(width: 750, height: 1334)..init(context);
    return Scaffold(
      body: Stack(
        children: <Widget>[
          MediaQuery.removePadding(
            removeTop: true,
            context: context,
            child: NotificationListener(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification && notification.depth == 0) {
                  _onScroll(notification.metrics.pixels);
                }
                return false;
              },
              child: CustomScrollView(controller: _controller, slivers: _sliverBuilder()),
            ),
          ),
          Container(
            height: appbarHeight + MediaQuery.of(context).padding.top,
            child: MyAppBar(
              barStyle: opacityValue < 0.3 ? StatusBarStyle.light : StatusBarStyle.dark,
              backgroundColor: Colors.white.withOpacity(1.0 * opacityValue),
              isBack: false,
              titleWidget: _buildTitle(),
            ),
          )
        ],
      ),
      floatingActionButton: _isShowToTopBtn
          ? HighLightWell(
              onTap: () {
                _controller.animateTo(0, duration: Duration(milliseconds: 200), curve: Curves.ease);
              },
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 35,
                height: 35,
                child: Image.asset(Images.arrowUpward),
              ),
            )
          : null,
    );
  }

  Widget _buildTitle() {
    return FlatButton(
      child: Text(
        '$_year-$_month',
        style: TextStyle(
            fontSize: ScreenUtil.getInstance().setSp(34),
            color: opacityValue < 0.3
                ? Colors.white.withOpacity(1.0 * (1 - opacityValue))
                : Colours.app_main.withOpacity(1.0 * opacityValue)),
      ),
      onPressed: () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return CalendarMonthDialog(
              checkTap: (year, month) {
                if (_year != year || _month != month) {
                  setState(() {
                    _year = year;
                    _month = month;
                    _getCurrentMonthData();
                  });
                }
              },
            );
          },
        );
      },
    );
  }

  List<Widget> _sliverBuilder() {
    return <Widget>[
      SliverAppBar(
        elevation: 0.0,
        pinned: false,
        expandedHeight: MediaQuery.of(context).padding.top + ScreenUtil.getInstance().setWidth(390),
        flexibleSpace: _flexibleSpaceBar(),
      ),
      _monthModel.recordList.length > 0
          ? SliverList(
              delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
                var model = _monthModel.recordList[index];
                if (model.runtimeType == BillRecordModel) {
                  return _buildItem(model);
                } else {
                  return _buildTimeTag(model);
                }
              }, childCount: _monthModel.recordList.length),
            )
          : SliverPadding(
              padding: EdgeInsets.only(top: ScreenUtil.getInstance().setHeight(120)),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
                  return const StateLayout(hintText: Strings.noBill);
                }, childCount: 1),
              ),
            ),
    ];
  }

  Widget _flexibleSpaceBar() {
    return FlexibleSpaceBar(
      background: Container(
        decoration: BoxDecoration(image: DecorationImage(image: AssetImage(Images.timg), fit: BoxFit.fill)),
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Text(
                      '${_monthModel.isBudget == 1 ? Utils.formatDouble(double.parse((_monthModel.budget - _monthModel.totalExpenses).toStringAsFixed(2))) : Utils.formatDouble(double.parse((_monthModel.totalRevenue - _monthModel.totalExpenses).toStringAsFixed(2)))}',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: ScreenUtil.getInstance().setSp(56),
                          color: Colors.white)),
                  Text(
                    '${Strings.currentMonth}${_monthModel.isBudget == 1 ? '${Strings.budget}' : ''}${Strings.balance}',
                    style: TextStyle(
                        fontWeight: FontWeight.w400, fontSize: ScreenUtil.getInstance().setSp(26), color: Colors.white),
                  ),
                  Gaps.vGap(ScreenUtil.getInstance().setHeight(15)),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: _amountWidget(),
            )
          ],
        ),
      ),
    );
  }

  Widget _amountWidget() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          flex: 1,
          child: Container(
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Positioned(
                  bottom: ScreenUtil.getInstance().setHeight(16),
                  child: Column(
                    children: <Widget>[
                      Text(
                        '${Utils.formatDouble(double.parse(_monthModel.totalExpenses.toStringAsFixed(2)))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: ScreenUtil.getInstance().setSp(36), color: Colors.white),
                      ),
                      Text('${Utils.formatDouble(double.parse(_month))} ${Strings.monthExpenses}',
                          style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: ScreenUtil.getInstance().setSp(26),
                              color: Colors.white))
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Positioned(
                  bottom: ScreenUtil.getInstance().setHeight(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '${Utils.formatDouble(double.parse(_monthModel.totalRevenue.toStringAsFixed(2)))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: ScreenUtil.getInstance().setSp(36), color: Colors.white),
                      ),
                      Text('${Utils.formatDouble(double.parse(_month))} ${Strings.monthRevenue}',
                          style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: ScreenUtil.getInstance().setSp(26),
                              color: Colors.white))
                    ],
                  ),
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildItem(BillRecordModel model) {
    return Container(
      child: HighLightWell(
          onTap: () {
            _showBottomSheet(model);
          },
          child: Stack(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Image.asset(Utils.getImagePath('${model.image}'), width: ScreenUtil.getInstance().setWidth(55)),
                        Gaps.hGap(12),
                        Text(model.categoryName,
                            style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: ScreenUtil.getInstance().setSp(32),
                                color: Colours.black)),
                        Expanded(
                          flex: 1,
                          child: Text('${Utils.formatDouble(model.money)}',
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: ScreenUtil.getInstance().setSp(36),
                                  color: Colours.dark)),
                        )
                      ],
                    ),
                    model.remark.isNotEmpty
                        ? Padding(
                            padding: EdgeInsets.only(left: ScreenUtil.getInstance().setWidth(55) + 12, top: 2),
                            child: Text(model.remark,
                                style: TextStyle(
                                    fontWeight: FontWeight.w300,
                                    fontSize: ScreenUtil.getInstance().setSp(30),
                                    color: Colours.black)),
                          )
                        : Gaps.empty,
                  ],
                ),
              ),
              Positioned(left: 16, right: 0, bottom: 0, child: Gaps.line)
            ],
          )),
    );
  }

  Widget _buildTimeTag(BillRecordGroup group) {
    String moneyString = '';
    if (group.totalRevenue > 0) {
      moneyString =
          moneyString + '${Strings.revenue} ${Utils.formatDouble(double.parse(group.totalRevenue.toStringAsFixed(2)))}';
    }
    if (group.totalExpenses > 0) {
      moneyString = moneyString +
          '${group.totalRevenue > 0 == true ? '  ' : ''}${Strings.edit} ${Utils.formatDouble(double.parse(group.totalExpenses.toStringAsFixed(2)))}';
    }

    return Container(
      color: Colors.white,
      width: double.infinity,
      child: HighLightWell(
        child: Stack(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Image.asset(Images.calendarIcon,
                          width: ScreenUtil.getInstance().setWidth(32)),
                      Gaps.hGap(10),
                      Text(group.date,
                          style: TextStyle(fontSize: ScreenUtil.getInstance().setSp(30), color: Colours.dark)),
                    ],
                  ),
                  Expanded(
                    child: Text(
                      moneyString,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ScreenUtil.getInstance().setSp(28),
                          color: Colours.dark),
                    ),
                  )
                ],
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: Gaps.line)
          ],
        ),
      ),
    );
  }

  _showBottomSheet(BillRecordModel model) {
    if (model == null) {
      Utils.show(Strings.queryError);
      return;
    }

    final TextStyle titleStyle = TextStyle(fontSize: 16, color: Colours.black);
    final TextStyle descStyle = TextStyle(fontSize: 16, color: Colours.black);

    DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    var dateTime = DateTime.fromMillisecondsSinceEpoch(model.updateTimestamp);
    String timeString = dateFormat.format(dateTime);

    showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  height: 60,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Text(Strings.billDetails, style: TextStyle(fontSize: 18)),
                      Positioned(
                        left: 0,
                        child: HighLightWell(
                          onTap: () {
                            dbHelp.deleteBillRecord(model.id).then((value) {
                              bus.trigger(bus.bookkeepingEventName);
                              NavigatorUtils.goBack(context);
                            });
                          },
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colours.gray_c, width: 0.5)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              child: Text(Strings.delete, style: TextStyle(fontSize: 16, color: Colors.red)),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: HighLightWell(
                          onTap: () {
                            NavigatorUtils.goBack(context);
                            Navigator.of(context).push(new MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (_) {
                                  return Bookkeeping(recordModel: model);
                                }));
                          },
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colours.gray_c, width: 0.5)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              child: Text(Strings.edit, style: TextStyle(fontSize: 16, color: Colours.black)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Gaps.line,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: <Widget>[
                      Text(Strings.amount, style: titleStyle),
                      Gaps.hGap(20),
                      Expanded(
                        flex: 1,
                        child: Text('${Utils.formatDouble(model.money)}',
                            textAlign: TextAlign.right, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                      )
                    ],
                  ),
                ),
                Gaps.line,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(Strings.sort, style: titleStyle),
                      Gaps.hGap(23),
                      Expanded(
                        flex: 1,
                        child: Container(
                          alignment: Alignment.centerRight,
                          width: double.infinity,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Image.asset(Utils.getImagePath('${model.image}'), width: 18),
                              Gaps.hGap(5),
                              Text('${model.categoryName}', textAlign: TextAlign.right, style: descStyle)
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                Gaps.line,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: <Widget>[
                      Text(Strings.date, style: titleStyle),
                      Gaps.hGap(20),
                      Expanded(
                        flex: 1,
                        child: Text('$timeString', textAlign: TextAlign.right, style: descStyle),
                      )
                    ],
                  ),
                ),
                Gaps.line,
                model.remark.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: <Widget>[
                            Text(Strings.remarks, style: titleStyle),
                            Gaps.hGap(20),
                            Expanded(
                              flex: 1,
                              child: Text('${model.remark}', textAlign: TextAlign.right, style: descStyle),
                            )
                          ],
                        ),
                      )
                    : Gaps.empty,
                MediaQuery.of(context).padding.bottom > 0
                    ? SizedBox(height: MediaQuery.of(context).padding.bottom)
                    : Gaps.empty,
              ],
            ),
          );
        });
  }
}

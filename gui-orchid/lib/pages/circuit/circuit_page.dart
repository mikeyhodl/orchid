import 'dart:async';
import 'package:dotted_border/dotted_border.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:orchid/api/orchid_api.dart';
import 'package:orchid/api/orchid_crypto.dart';
import 'package:orchid/api/orchid_eth/v0/orchid_eth_v0.dart';
import 'package:orchid/api/orchid_log_api.dart';
import 'package:orchid/api/orchid_types.dart';
import 'package:orchid/api/preferences/user_preferences.dart';
import 'package:orchid/api/orchid_eth/v0/orchid_market_v0.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:orchid/common/app_sizes.dart';
import 'package:orchid/common/app_reorderable_list.dart';
import 'package:orchid/common/app_dialogs.dart';
import 'package:orchid/common/formatting.dart';
import 'package:orchid/common/link_text.dart';
import 'package:orchid/common/titled_page_base.dart';
import 'package:orchid/orchid/orchid_panel.dart';
import 'package:orchid/orchid/orchid_text.dart';
import 'package:orchid/pages/account_manager/account_card.dart';
import 'package:orchid/pages/account_manager/account_detail_store.dart';
import 'package:orchid/pages/circuit/config_change_dialogs.dart';

import '../../common/app_gradients.dart';
import '../../common/app_text.dart';
import 'add_hop_page.dart';
import 'hop_editor.dart';
import 'hop_tile.dart';
import 'model/circuit.dart';
import 'model/circuit_hop.dart';
import 'model/orchid_hop.dart';

// The V0 multi-hop config page.
class CircuitPage extends StatefulWidget {
  // Note: This performs a behavior like the iOSContacts App create flow for the
  // Note: add hop action, revealing the already pushed hop editor upon completing
  // Note: the add flow.
  static var iOSContactsStyleAddHopBehavior = false;

  CircuitPage({Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return new CircuitPageState();
  }
}

class CircuitPageState extends State<CircuitPage>
    with TickerProviderStateMixin {
  List<StreamSubscription> _rxSubs = [];
  List<UniqueHop> _hops;

  bool _dialogInProgress = false; // ?

  AccountDetailStore _accountDetailStore;

  @override
  void initState() {
    super.initState();
    _accountDetailStore =
        AccountDetailStore(onAccountDetailChanged: _accountDetailChanged);
    initStateAsync();
  }

  void initStateAsync() async {
    OrchidAPI().circuitConfigurationChanged.listen((_) {
      _updateCircuit();
    });
    // Update the UI on connection status changes
    _rxSubs.add(OrchidAPI().vpnRoutingStatus.listen(_connectionStateChanged));
  }

  void _updateCircuit() async {
    var circuit = await UserPreferences().getCircuit();
    if (mounted) {
      setState(() {
        var keyBase = DateTime.now().millisecondsSinceEpoch;
        // Wrap the hops with a locally unique id for the UI
        _hops = UniqueHop.wrap(circuit.hops, keyBase);
      });

      // Set the correct animation states for the connection status
      // Note: We cannot properly do this until we know if we have hops!
      log('init state, setting initial connection state');
      _connectionStateChanged(OrchidAPI().vpnRoutingStatus.value,
          animated: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TitledPage(
      title: "Circuit Builder",
      decoration: BoxDecoration(),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    return _buildHopList();
  }

  Widget _buildHopList() {
    // Note: this view needs to be full screen vertical in order to scroll off-edge properly.
    return AppReorderableListView(
        header: Column(
          children: <Widget>[
            _buildStatusTile(),
            pady(40),
          ],
        ),
        children: (_hops ?? []).map((uniqueHop) {
          return _buildDismissableHopTile(uniqueHop);
        }).toList(),
        footer: Column(
          children: <Widget>[
            _buildNewHopTile(),
            if (!_hasHops()) pady(16),
            _buildDeletedHopsLink(),
          ],
        ),
        onReorder: _onReorder);
  }

  Widget _buildNewHopTile() {
    return GestureDetector(
      onTap: _addHop,
      child: DottedBorder(
          color: Color(0xffb88dfc),
          strokeWidth: 2.0,
          dashPattern: [8, 10],
          radius: Radius.circular(10),
          borderType: BorderType.RRect,
          child: Container(
            width: 328,
            height: 72,
            child: Center(
                child: Text("ADD NEW HOP", style: OrchidText.button.tappable)),
          )),
    );
  }

  Widget _buildDeletedHopsLink() {
    return Container(
      height: 45,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: LinkText(
          s.viewDeletedHops,
          style: OrchidText.caption.linkStyle,
          onTapped: () {
            Navigator.pushNamed(context, '/settings/accounts');
          },
        ),
      ),
    );
  }

  Widget _buildStatusTile() {
    String text = s.orchidDisabled;
    Color color = Colors.redAccent.withOpacity(0.7);
    if (_connected()) {
      if (_hasHops()) {
        var num = _hops.length;
        text = s.numHopsConfigured(num);
        color = Colors.greenAccent.withOpacity(0.7);
      } else {
        text = s.trafficMonitoringOnly;
        color = Colors.yellowAccent.withOpacity(0.7);
      }
    }

    var status = OrchidAPI().vpnRoutingStatus.value;
    if (status == OrchidVPNRoutingState.VPNConnecting) {
      text = s.starting;
      color = Colors.yellowAccent.withOpacity(0.7);
    }
    if (status == OrchidVPNRoutingState.VPNConnected) {
      text = s.orchidConnecting;
      color = Colors.yellowAccent.withOpacity(0.7);
    }
    if (status == OrchidVPNRoutingState.VPNDisconnecting) {
      text = s.orchidDisconnecting;
      color = Colors.yellowAccent.withOpacity(0.7);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.fiber_manual_record, color: color, size: 18),
          padx(5),
          Text(text,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: Colors.white,
              )),
        ],
      ),
    );
  }

  Widget _buildDismissableHopTile(UniqueHop uniqueHop) {
    return Padding(
      key: Key(uniqueHop.key.toString()),
      padding: const EdgeInsets.only(bottom: 28.0),
      child: Dismissible(
        key: Key(uniqueHop.key.toString()),
        background: buildDismissableBackground(context),
        confirmDismiss: _confirmDeleteHop,
        onDismissed: (direction) {
          _deleteHop(uniqueHop);
        },
        child: _buildTappableHopTile(uniqueHop),
      ),
    );
  }

  static Container buildDismissableBackground(BuildContext context) {
    return Container(
      color: Colors.red,
      child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              S.of(context).delete,
              style: TextStyle(color: Colors.white),
            ),
          )),
    );
  }

  Widget _buildTappableHopTile(UniqueHop uniqueHop) {
    return GestureDetector(
      onTap: () {
        _viewHop(uniqueHop);
      },
      // Don't allow the cards to expand, etc.
      child: AbsorbPointer(
        child: _buildHopTile(uniqueHop),
      ),
    );
  }

  Widget _buildHopTile(UniqueHop uniqueHop) {
    switch (uniqueHop.hop.protocol) {
      case HopProtocol.Orchid:
        var hop = uniqueHop.hop as OrchidHop;
        var accountDetail = _accountDetailStore.get(hop.account);
        return AccountCard(
          accountDetail: accountDetail,
          minHeight: true,
        );
        break;
      case HopProtocol.OpenVPN:
      case HopProtocol.WireGuard:
        return _buildOtherHopTile(uniqueHop);
        break;
    }
    throw Exception();
  }

  // Note: We should integrate this into AccountCard
  Widget _buildOtherHopTile(UniqueHop hop) {
    Widget icon = Container();
    Widget text = Container();
    switch (hop.hop.protocol) {
      case HopProtocol.Orchid:
        break;
      case HopProtocol.OpenVPN:
        icon =
            SvgPicture.asset('assets/svg/openvpn.svg', width: 38, height: 38);
        text = Text(s.openVPNHop).title;
        break;
      case HopProtocol.WireGuard:
        icon =
            SvgPicture.asset('assets/svg/wireguard.svg', width: 40, height: 40);
        text = Text(s.wireguardHop).title;
        break;
    }
    // Match account card for now
    return SizedBox(
      width: 334,
      height: 74,
      child: OrchidPanel(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(width: 40, child: icon),
            text,
            SizedBox(width: 40)
          ],
        ),
      )),
    );
  }

  // switch deleted hops to use new tiles
  @deprecated
  static Widget buildHopTile({
    @required BuildContext context,
    @required UniqueHop uniqueHop,
    VoidCallback onTap,
    Color bgColor,
    bool showAlertBadge,
  }) {
    Color color = Colors.white;
    Image image;
    String svgName;
    switch (uniqueHop.hop.protocol) {
      case HopProtocol.Orchid:
        image = Image.asset('assets/images/logo2.png', color: color);
        break;
      case HopProtocol.OpenVPN:
        svgName = 'assets/svg/openvpn.svg';
        break;
      case HopProtocol.WireGuard:
        svgName = 'assets/svg/wireguard.svg';
        break;
    }
    var title = uniqueHop.hop.displayName(context);
    return HopTile(
      showAlertBadge: showAlertBadge,
      textColor: color,
      color: bgColor ?? Colors.white,
      image: image,
      svgName: svgName,
      onTap: onTap,
      key: Key(uniqueHop.key.toString()),
      title: title,
      showTopDivider: false,
    );
  }

  ///
  /// Begin - Add / view hop logic
  ///

  void _addHop() async {
    CircuitUtils.addHop(context, onComplete: _addHopComplete);
  }

  // Local page state updates after hop addition.
  void _addHopComplete(UniqueHop uniqueHop) {
    // TODO: needed? Or does the global config change handle it?
    setState(() {
      _hops.add(uniqueHop);
    });

    // View the newly created hop:
    // Note: This performs a behavior like the iOS-Contacts App add flow,
    // Note: revealing the already pushed navigation state upon completing the
    // Note: add flow.  This non-animated push approximates this.
    if (CircuitPage.iOSContactsStyleAddHopBehavior) {
      _viewHop(uniqueHop, animated: false);
    }
  }

  void _saveCircuit() async {
    var circuit = Circuit(_hops.map((uniqueHop) => uniqueHop.hop).toList());
    CircuitUtils.saveCircuit(circuit);
    _showConfigurationChangedDialog();
  }

  void _showConfigurationChangedDialog() async {
    if (_dialogInProgress) {
      return;
    }
    try {
      _dialogInProgress = true;
      await ConfigChangeDialogs.showConfigurationChangeSuccess(context,
          warnOnly: true);
    } finally {
      _dialogInProgress = false;
    }
  }

  // View a hop selected from the circuit list
  void _viewHop(UniqueHop uniqueHop, {bool animated = true}) async {
    EditableHop editableHop = EditableHop(uniqueHop);
    HopEditor editor = editableHop.editor();
    await editor.show(context, animated: animated);

    // TODO: avoid saving if the hop was not edited.
    // Save the hop if it was edited.
    var index = _hops.indexOf(uniqueHop);
    setState(() {
      _hops.removeAt(index);
      _hops.insert(index, editableHop.value);
    });
    _saveCircuit();
  }

  // Callback for swipe to delete
  Future<bool> _confirmDeleteHop(dismissDirection) async {
    var result = await AppDialogs.showConfirmationDialog(
      context: context,
      title: s.confirmDelete,
      bodyText: s.deletingThisHopWillRemoveItsConfiguredOrPurchasedAccount +
          "  " +
          s.ifYouPlanToReuseTheAccountLaterYouShould,
    );
    return result;
  }

  // Callback for swipe to delete
  void _deleteHop(UniqueHop uniqueHop) async {
    var index = _hops.indexOf(uniqueHop);
    var removedHop = _hops.removeAt(index);
    setState(() {});
    _saveCircuit();
    // _recycleHopIfAllowed(uniqueHop);
    UserPreferences().addRecentlyDeletedHop(removedHop.hop);
  }

  // Callback for drag to reorder
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final UniqueHop hop = _hops.removeAt(oldIndex);
      _hops.insert(newIndex, hop);
    });
    _saveCircuit();
  }

  ///
  /// Begin - VPN Connection Status Logic
  ///

  // Note: By design the switch on this page does not track or respond to the
  // Note: connection state after initialization.  See `monitoring_page.dart`
  // Note: for a version of the switch that does attempt to track the connection.
  bool _connected() {
    var state = OrchidAPI().vpnRoutingStatus.value;
    switch (state) {
      case OrchidVPNRoutingState.VPNDisconnecting:
      case OrchidVPNRoutingState.VPNNotConnected:
      case OrchidVPNRoutingState.VPNConnecting:
      case OrchidVPNRoutingState.VPNConnected:
        return false;
      case OrchidVPNRoutingState.OrchidConnected:
        return true;
      default:
        throw Exception();
    }
  }

  /// Called upon a change to Orchid connection state
  void _connectionStateChanged(OrchidVPNRoutingState state,
      {bool animated = true}) {
    if (mounted) {
      setState(() {});
    }
  }

  ///
  /// Begin - util
  ///

  bool _hasHops() {
    return _hops != null && _hops.length > 0;
  }

  void _accountDetailChanged() {
    if (mounted) {
      setState(() {}); // Trigger a UI refresh
    }
  }

  S get s {
    return S.of(context);
  }

  @override
  void dispose() {
    _accountDetailStore.dispose();
    _rxSubs.forEach((sub) {
      sub.cancel();
    });
    super.dispose();
  }
}

typedef HopCompletion = void Function(UniqueHop);

class CircuitUtils {
  // Show the add hop flow and save the result if completed successfully.
  static void addHop(BuildContext context, {HopCompletion onComplete}) async {
    // Create a nested navigation context for the flow. Performing a pop() from
    // this outer context at any point will properly remove the entire flow
    // (possibly multiple screens) with one appropriate animation.
    Navigator addFlow = Navigator(
      onGenerateRoute: (RouteSettings settings) {
        var addFlowCompletion = (CircuitHop result) {
          Navigator.pop(context, result);
        };
        var editor = AddHopPage(onAddFlowComplete: addFlowCompletion);
        var route = MaterialPageRoute<CircuitHop>(
            builder: (context) => editor, settings: settings);
        return route;
      },
    );
    var route = MaterialPageRoute<CircuitHop>(
        builder: (context) => addFlow, fullscreenDialog: true);
    _pushNewHopEditorRoute(context, route, onComplete);
  }

  // Push the specified hop editor to create a new hop, await the result, and
  // save it to the circuit.
  // Note: The paradigm here of the hop editors returning newly created or edited hops
  // Note: on the navigation stack decouples them but makes them more dependent on
  // Note: this update and save logic. We should consider centralizing this logic and
  // Note: relying on observation with `OrchidAPI.circuitConfigurationChanged` here.
  // Note: e.g.
  // Note: void _AddHopExternal(CircuitHop hop) async {
  // Note:   var circuit = await UserPreferences().getCircuit() ?? Circuit([]);
  // Note:   circuit.hops.add(hop);
  // Note:   await UserPreferences().setCircuit(circuit);
  // Note:   OrchidAPI().updateConfiguration();
  // Note:   OrchidAPI().circuitConfigurationChanged.add(null);
  // Note: }
  static void _pushNewHopEditorRoute(BuildContext context,
      MaterialPageRoute route, HopCompletion onComplete) async {
    var hop = await Navigator.push(context, route);
    if (hop == null) {
      return; // user cancelled
    }
    var uniqueHop =
        UniqueHop(hop: hop, key: DateTime.now().millisecondsSinceEpoch);
    addHopToCircuit(uniqueHop.hop);
    if (onComplete != null) {
      onComplete(uniqueHop);
    }
  }

  static void addHopToCircuit(CircuitHop hop) async {
    var circuit = await UserPreferences().getCircuit();
    circuit.hops.add(hop);
    saveCircuit(circuit);
  }

  static void saveCircuit(Circuit circuit) async {
    try {
      log("XXX: Saving circuit: ${circuit.hops.map((e) => e.toJson())}");
      UserPreferences().setCircuit(circuit);
    } catch (err, stack) {
      log("Error saving circuit: $err, $stack");
    }
    OrchidAPI().updateConfiguration();
    OrchidAPI().circuitConfigurationChanged.add(null);
  }
}

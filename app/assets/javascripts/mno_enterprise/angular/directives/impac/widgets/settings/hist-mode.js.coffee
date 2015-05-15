module = angular.module('maestrano.impac.widgets.settings.hist-mode',['maestrano.assets'])

module.controller('WidgetSettingHistModeCtrl',
  ['$scope', 'ImpacDashboardingSvc',
  ($scope, ImpacDashboardingSvc) ->

    w = $scope.parentWidget
    w.isHistoryMode = false

    $scope.toogleHistMode = (mode) ->
      return if (w.isHistoryMode && mode == 'history') || (!w.isHistoryMode && mode =='current')
      w.isHistoryMode = !w.isHistoryMode
      w.updateSettings(false)

    # What will be passed to parentWidget
    setting = {}
    setting.key = "hist-mode"
    setting.isInitialized = false

    # initialization of time range parameters from widget.content.hist_parameters
    setting.initialize = ->
      if w.content? && w.content.hist_parameters? && mode = w.content.hist_parameters.mode
        if mode == 'history' 
          w.isHistoryMode = true
        else
          w.isHistoryMode = false
        setting.isInitialized = true

    setting.toMetadata = ->
      if w.isHistoryMode
        mode = 'history'
      else
        mode = 'current'
      return {hist_parameters: {mode: mode}}

    w.settings ||= []
    w.settings.push(setting)
])

module.directive('widgetSettingHistMode', ['TemplatePath', (TemplatePath) ->
  return {
    restrict: 'A',
    scope: {
      parentWidget: '='
    },
    templateUrl: TemplatePath['mno_enterprise/impac/widgets/settings/hist-mode.html'],
    controller: 'WidgetSettingHistModeCtrl'
  }
])
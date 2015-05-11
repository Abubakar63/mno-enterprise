module = angular.module('maestrano.impac.widgets.settings.time-range',['maestrano.assets'])

module.controller('WidgetSettingTimeRangeCtrl', ['$scope', ($scope) ->

  w = $scope.parentWidget

  $scope.numberOfPeriods = (new Date()).getMonth() + 1
  $scope.selectedPeriod = "MONTHLY"
  $scope.PERIODS = ['DAILY','WEEKLY','MONTHLY','QUARTERLY','YEARLY']

  $scope.periodToUnit = ->
    nb = $scope.numberOfPeriods
    period = $scope.selectedPeriod
    if period != "DAILY"
      unit = period.substring(0,period.length-2).toLowerCase()
    else
      unit = "day"
    if nb > 1
      unit = unit.concat("s")
    return unit

  # What will be passed to parentWidget
  setting = {}
  setting.key = "time-range"
  setting.isInitialized = false

  # initialization of time range parameters from widget.content.hist_parameters
  setting.initialize = ->
    if w.content? && hist = w.content.hist_parameters
      $scope.selectedPeriod = hist.period if hist.period?
      $scope.numberOfPeriods = hist.number_of_periods if hist.number_of_periods?
      setting.isInitialized = true

  setting.toMetadata = ->
    return { hist_parameters: {period: $scope.selectedPeriod, number_of_periods: $scope.numberOfPeriods} }

  w.settings ||= []
  w.settings.push(setting)
])

module.directive('widgetSettingTimeRange', ['TemplatePath', (TemplatePath) ->
  return {
    restrict: 'A',
    scope: {
      parentWidget: '='
    },
    templateUrl: TemplatePath['mno_enterprise/impac/widgets/settings/time-range.html'],
    controller: 'WidgetSettingTimeRangeCtrl'
  }
])
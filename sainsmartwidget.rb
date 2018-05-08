require 'Qt4'
require_relative 'ui_sainsmartwidget'

class SainsmartWidget < Qt::Widget
  slots 'target()'
  slots 'updateBaseSpin(int)'
  slots 'updateShoulderSpin(int)'
  slots 'updateElbowSpin(int)'
  slots 'updateRollSpin(int)'
  slots 'updatePitchSpin(int)'
  slots 'updateWristSpin(int)'
  slots 'updateGripperGroup(double)'
  slots 'updateGripperOpen(bool)'
  slots 'saveTeachPoint()'
  slots 'loadTeachPoint()'
  slots 'stop()'

  attr_reader :ui

  # Fix "/usr/lib/ruby/vendor_ruby/2.3.0/Qt/qtruby4.rb:187:in `find_pclassid'" when running rspec.
  def self.name
    'SainsmartWidget'
  end

  def initialize client, parent = nil
    super parent
    @client = client
    @ui = Ui::SainsmartWidget.new
    @ui.setupUi self
    @spin_boxes = [@ui.baseSpin, @ui.shoulderSpin, @ui.elbowSpin, @ui.rollSpin, @ui.pitchSpin, @ui.wristSpin, @ui.gripperSpin]
    connect @ui.baseSlider    , SIGNAL('valueChanged(int)'   ), self, SLOT('updateBaseSpin(int)'         )
    connect @ui.shoulderSlider, SIGNAL('valueChanged(int)'   ), self, SLOT('updateShoulderSpin(int)'     )
    connect @ui.elbowSlider   , SIGNAL('valueChanged(int)'   ), self, SLOT('updateElbowSpin(int)'        )
    connect @ui.rollSlider    , SIGNAL('valueChanged(int)'   ), self, SLOT('updateRollSpin(int)'         )
    connect @ui.pitchSlider   , SIGNAL('valueChanged(int)'   ), self, SLOT('updatePitchSpin(int)'        )
    connect @ui.wristSlider   , SIGNAL('valueChanged(int)'   ), self, SLOT('updateWristSpin(int)'        )

    connect @ui.gripperSpin, SIGNAL('valueChanged(double)'), self, SLOT('updateGripperGroup(double)')
    connect @ui.gripperOpen, SIGNAL('toggled(bool)'), self, SLOT('updateGripperOpen(bool)')

    connect @ui.stopButton, SIGNAL('clicked()'), self, SLOT('stop()')
    connect @ui.saveButton, SIGNAL('clicked()'), self, SLOT('saveTeachPoint()')
    connect @ui.loadButton, SIGNAL('clicked()'), self, SLOT('loadTeachPoint()')
    @spin_boxes.zip(client.lower, client.upper).each do |spin_box, lower, upper|
      spin_box.minimum = lower
      spin_box.maximum = upper
    end
    @ui.gripperOpenSpin.minimum = @ui.gripperSpin.minimum
    @ui.gripperOpenSpin.maximum = @ui.gripperSpin.maximum
    @ui.gripperCloseSpin.minimum = @ui.gripperSpin.minimum
    @ui.gripperCloseSpin.maximum = @ui.gripperSpin.maximum
    update_controls @client.pos
    sync @ui.baseSlider, @ui.baseSpin
    sync @ui.shoulderSlider, @ui.shoulderSpin
    sync @ui.elbowSlider, @ui.elbowSpin
    sync @ui.rollSlider, @ui.rollSpin
    sync @ui.pitchSlider, @ui.pitchSpin
    sync @ui.wristSlider, @ui.wristSpin
    @ui.gripperOpenSpin.value = @ui.gripperSpin.value
    @timer = nil
  end

  def update_controls configuration
    @spin_boxes.zip(configuration).each do |spin_box, pos|
      disconnect spin_box, SIGNAL('valueChanged(double)'), self, SLOT('target()')
      spin_box.value = pos
      connect spin_box, SIGNAL('valueChanged(double)'), self, SLOT('target()')
    end
  end

  def timerEvent e
    pending if e.timerId == @timer
  end

  def keyPressEvent e
    if e.key == Qt.Key_Escape
      stop
    elsif e.key >= Qt.Key_A and e.key <= Qt.Key_L
      @ui.teachPointCombo.setCurrentIndex e.key - Qt.Key_A
    end
  end

  def values
    @spin_boxes.collect { |spin_box| spin_box.value }
  end

  def defer
    @timer = startTimer 100 unless @timer
  end

  def ready? *values
    unless @client.ready?
      false
    else
      # Check that half of time required to reach new target is greater or equal remaining time required of current path.
      2 * @client.time_remaining <= @client.time_required(*values)
    end
  end

  def target
    vals = values
    if ready? *vals
      p vals
      @client.target *vals
    else
      defer
    end
  end

  def sync dest, source
    dest.value = (dest.maximum - dest.minimum) * (source.value - source.minimum) / (source.maximum - source.minimum) + dest.minimum
  end

  def updateBaseSpin value
    sync @ui.baseSpin, @ui.baseSlider
  end

  def updateShoulderSpin value
    sync @ui.shoulderSpin, @ui.shoulderSlider
  end

  def updateElbowSpin value
    sync @ui.elbowSpin, @ui.elbowSlider
  end

  def updateRollSpin value
    sync @ui.rollSpin, @ui.rollSlider
  end

  def updatePitchSpin value
    sync @ui.pitchSpin, @ui.pitchSlider
  end

  def updateWristSpin value
    sync @ui.wristSpin, @ui.wristSlider
  end

  def updateGripperGroup value
    sync @ui.gripperOpen.isChecked ? @ui.gripperOpenSpin : @ui.gripperCloseSpin, @ui.gripperSpin
  end

  def updateGripperOpen value
    sync @ui.gripperSpin, value ? @ui.gripperOpenSpin : @ui.gripperCloseSpin
  end

  def teach_point_index
    @ui.teachPointCombo.currentIndex
  end

  def saveTeachPoint
    @client.save_teach_point teach_point_index
  end

  def loadTeachPoint
    update_controls @client.load_teach_point(teach_point_index)
  end

  def kill_timer
    if @timer
      killTimer @timer
      @timer = nil
    end
  end

  def stop
    @client.stop
    kill_timer
    update_controls @client.pos
  end

  def pending
    kill_timer
    target
  end
end

# NeuroBrain Motor API
# Şimdilik donanımdan bağımsız boş fonksiyonlar.

def motor_left_forward(speed=1.0):
    pass

def motor_left_reverse(speed=1.0):
    pass

def motor_right_forward(speed=1.0):
    pass

def motor_right_reverse(speed=1.0):
    pass

def motors_forward(speed=1.0):
    motor_left_forward(speed)
    motor_right_forward(speed)

def motors_reverse(speed=1.0):
    motor_left_reverse(speed)
    motor_right_reverse(speed)

def motors_stop():
    pass

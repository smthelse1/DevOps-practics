import pika

# Параметры подключения
credentials = pika.PlainCredentials('user', 'root')
parameters = pika.ConnectionParameters(
    host='localhost',
    port=5672,
    virtual_host='VHost',
    credentials=credentials
)

# Подключение к RabbitMQ
connection = pika.BlockingConnection(parameters)
channel = connection.channel()

# Создание очереди (если она еще не создана)
channel.queue_declare(queue='justqueue')

# Отправка сообщения
message = "Hello, RabbitMQ!"
channel.basic_publish(exchange='',
                      routing_key='justqueue',
                      body=message)

print(f" [x] Sent '{message}'")

# Закрытие соединения
connection.close()

import pika
import time

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

# Создание обменника
exchange_name = 'direct_exchange'
channel.exchange_declare(exchange=exchange_name, exchange_type='direct')

# Создание очереди (если она еще не создана)
queue_name = 'justqueue'
channel.queue_declare(queue=queue_name)

# Связывание очереди с обменником через routing key
routing_key = 'example_routing_key'
channel.queue_bind(exchange=exchange_name, queue=queue_name, routing_key=routing_key)

# Функция обратного вызова для обработки сообщений
def callback(ch, method, properties, body):
    print(f" [x] Received {body}")
    time.sleep(2)  # Искусственная задержка для имитации обработки
    print(f" [x] Done processing {body}")
    ch.basic_ack(delivery_tag=method.delivery_tag)  # Подтверждение обработки сообщения

# Получение сообщений с auto_ack=False
channel.basic_consume(queue=queue_name,
                      on_message_callback=callback,
                      auto_ack=False)

print(' [*] Waiting for messages. To exit press CTRL+C')
channel.start_consuming()
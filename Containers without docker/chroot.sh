#!/bin/bash

CHROOT_DIR="/mnt/chroot"

if [ ! -d "$CHROOT_DIR" ]; then
  echo "❌ Ошибка: директория $CHROOT_DIR не существует."
  exit 1
fi

echo "🔧 Монтируем необходимые виртуальные ФС..."

mount -t proc proc "$CHROOT_DIR/proc"

# sys
mount --rbind /sys "$CHROOT_DIR/sys"
mount --make-rslave "$CHROOT_DIR/sys"

# dev
mount --rbind /dev "$CHROOT_DIR/dev"
mount --make-rslave "$CHROOT_DIR/dev"

# optionally
mount --rbind /run "$CHROOT_DIR/run"
mount --make-rslave "$CHROOT_DIR/run"

echo "✅ Всё смонтировано. Входим в chroot..."

chroot "$CHROOT_DIR" /bin/bash

echo "🚪 Выход из chroot. Отмонтируем всё обратно..."

umount -l "$CHROOT_DIR/proc"
umount -l "$CHROOT_DIR/sys"
umount -l "$CHROOT_DIR/dev"
umount -l "$CHROOT_DIR/run"

echo "🧹 Готово! Chroot-сессия завершена безопасно."

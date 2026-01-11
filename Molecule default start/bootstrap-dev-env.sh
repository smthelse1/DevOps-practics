#!/usr/bin/env bash
set -e

echo "=== 1. Установка Python 3.10 ==="
if ! command -v python3.10 &> /dev/null; then
    sudo apt update
    sudo apt install -y software-properties-common
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt update
    sudo apt install -y python3.10 python3.10-venv python3.10-dev python3.10-distutils curl
fi

PYTHON=python3.10
echo "Python version: $($PYTHON --version)"

echo "=== 2. Создаем виртуальное окружение ==="
rm -rf .venv
$PYTHON -m venv .venv
source .venv/bin/activate

echo "=== 3. Обновляем pip/setuptools/wheel ==="
pip install --upgrade pip setuptools wheel

echo "=== 4. Устанавливаем ansible/molecule и фиксируем версии ==="
pip install ansible-core==2.13.13 molecule==4.0.4 molecule-docker==2.1.0

echo "=== 5. Фиксим ansible-compat для Molecule 4 ==="
pip uninstall -y ansible-compat || true
pip install "ansible-compat<4"

echo "=== 6. Устанавливаем коллекции Ansible ==="
if [ -f "/var/apps/ansible/collections/collections.yml" ]; then
    ansible-galaxy collection install -r /var/apps/ansible/collections/collections.yml
else
    echo "collections.yml не найден, пропускаем"
fi

echo "=== 7. Проверяем версии ==="
ansible --version
molecule --version

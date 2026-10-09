# 📱 Finanças Casal • Rodrigo & Márcia (Flutter + Supabase)

Aplicativo móvel nativo de gestão financeira familiar para **Rodrigo & Márcia**, desenvolvido com **Flutter**, **Supabase (PostgreSQL + Realtime)**, **Google ML Kit (OCR de Notas Fiscais)** e **Reconhecimento de Voz Nativo**.

---

## 🚀 Como Conectar ao Supabase (Passo a Passo em 3 Minutos)

### 1. Criar o Projeto Gratuito
1. Acesse [supabase.com](https://supabase.com) e faça login gratuito (com GitHub ou e-mail).
2. Clique em **New Project**, dê o nome de `financas-casal` e escolha uma senha segura para o banco.
3. Selecione a região **São Paulo (sa-east-1)** ou a mais próxima.

### 2. Executar os Scripts SQL
1. No menu lateral esquerdo do Supabase, clique em **SQL Editor** (ícone de terminal `>_`).
2. Clique em **+ New query**, copie o conteúdo do arquivo `supabase_schema.sql` e clique em **RUN**.
   - *Isso cria todas as tabelas (`transactions`, `credit_cards`, `cycles`, etc.), ativa o Realtime e as regras de segurança.*
3. Abra uma nova query, copie o conteúdo de `supabase_migration_212_transactions.sql` e clique em **RUN**.
   - *Isso importa imediatamente todos os **212 lançamentos históricos** de Rodrigo & Márcia com 100% de integridade!*

### 3. Colocar as Chaves no Aplicativo
1. No Supabase, vá em **Project Settings** (ícone de engrenagem) -> **API**.
2. Copie a **Project URL** e a chave **anon / public**.
3. Abra o arquivo `lib/config/supabase_config.dart` e cole os valores:
   ```dart
   static const String supabaseUrl = 'https://seu-projeto.supabase.co';
   static const String supabaseAnonKey = 'sua-anon-key-aqui';
   ```

---

## 🎙️ Como Funciona o Reconhecimento de Voz Nativo
- Utiliza a biblioteca `speech_to_text`, comunicando-se **diretamente com o microfone do celular** via APIs nativas do Android e iOS (`android.permission.RECORD_AUDIO`).
- **Sem restrições de HTTPS do navegador**: Funciona com 1 toque no botão circular do microfone.
- **Motor NLP integrado** em `lib/services/speech_service.dart`:
  - Reconhece gastos como *"Almoço 45 reais no débito"* ou *"Ração do cachorro 120 no pix"* e preenche categoria (incluindo `🐾 Pet`), valor e forma de pagamento automaticamente!

---

## 📸 Como Funciona o OCR de Cupons Fiscais
- Utiliza o **Google ML Kit Text Recognition** (`google_mlkit_text_recognition`), processando a imagem diretamente na GPU do aparelho.
- Sem internet necessária para ler o cupom.
- Extrai automaticamente o valor total (`TOTAL`, `VALOR A PAGAR`) e o nome da loja, deixando o campo limpo para confirmação.

---

## 💵 Máscara Automática de Centavos
- Ao digitar valores em qualquer formulário, o app divide automaticamente por 100:
  - Digitar `1` vira `R$ 0,01`
  - Digitar `15` vira `R$ 0,15`
  - Digitar `150` vira `R$ 1,50`
  - Digitar `15000` vira `R$ 150,00`

---

## 🛠️ Como Executar o App no Celular ou Emulador

### Requisitos:
- Flutter SDK instalado no Windows.
- Dispositivo Android conectado via USB (com depuração USB ativada) ou emulador.

### Comandos:
```bash
# 1. Baixar as dependências
flutter pub get

# 2. Executar no celular em tempo real
flutter run

# 3. Gerar o arquivo instalador APK para instalar no celular
flutter build apk --release
```
O arquivo final `.apk` será gerado em `build/app/outputs/flutter-apk/app-release.apk` pronto para envio pelo WhatsApp ou cabo para os celulares de Rodrigo e Márcia!

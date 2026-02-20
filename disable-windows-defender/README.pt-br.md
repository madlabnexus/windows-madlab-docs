# Desabilitar Windows Defender Permanentemente em VM Windows 11

🇺🇸 [English version](README.md)

## Por quê

O Windows Defender consome CPU e RAM significativos em uma VM. Como esta é uma estação de trabalho virtualizada para Office rodando atrás da segurança de rede do host, o Defender é um overhead desnecessário.

## Pré-requisitos

- VM Windows 11 em execução
- Acesso com conta de administrador

---

## Passo 1: Desativar Proteção contra Violação (Manual - Apenas GUI)

A Proteção contra Violação impede que scripts modifiquem as configurações do Defender. Ela **não pode** ser desativada via script — a Microsoft exige interação manual pela GUI.

1. Abra **Configurações**
2. Vá em **Privacidade e Segurança** → **Segurança do Windows**
3. Clique em **Proteção contra vírus e ameaças**
4. Role até **Configurações de proteção contra vírus e ameaças** → clique em **Gerenciar configurações**
5. Role até **Proteção contra Violação** → desative (**Desligado**)
6. Confirme o prompt do UAC

> **Importante:** NÃO pule este passo. Os scripts abaixo falharão silenciosamente ou com erros se a Proteção contra Violação ainda estiver ativada.

---

## Passo 2: Executar o Script Principal de Desativação (Modo Normal)

Este script desativa políticas do Defender, SmartScreen, notificações, tarefas agendadas e outros serviços desnecessários da VM.

1. Abra o **Menu Iniciar**
2. Digite `PowerShell`
3. Clique com botão direito em **Windows PowerShell** → **Executar como administrador**
4. Execute:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd ~\Downloads
.\disable-defender.ps1
```

### O que este script faz:

| Ação | Objetivo |
|------|----------|
| Desativa monitoramento em tempo real | Para a varredura ativa de arquivos |
| Define chaves de registro de Política de Grupo | Impede que o Defender se reative |
| Desativa SmartScreen | Para verificações de reputação de apps |
| Oculta notificações da Central de Segurança | Sem mais alertas na barra de tarefas |
| Oculta ícone do systray | Remove ícone de escudo da barra de tarefas |
| Desativa tarefas agendadas de varredura | Sem varreduras em segundo plano |
| Desativa SysMain (Superfetch) | Libera RAM (desnecessário em VM) |
| Desativa DiagTrack (Telemetria) | Para envio de dados para Microsoft |
| Desativa GameBar/GameDVR | Não necessário em VM de Office |
| Desativa Serviço de Display NVIDIA | Sem GPU na VM, serviço desperdiça recursos |

---

## Passo 3: Desabilitar TODOS os Serviços do Defender via Modo Seguro

As chaves de registro dos serviços do Defender são de propriedade do **TrustedInstaller**, uma conta especial do Windows com privilégios superiores ao Administrador ou mesmo SYSTEM. A única forma confiável de modificar essas chaves é no **Modo Seguro**, onde o Defender não executa e sua autoproteção está inativa.

### 3a: Entrar no Modo Seguro

Abra PowerShell como Admin e execute:

```powershell
bcdedit /set "{current}" safeboot minimal
Restart-Computer
```

O Windows reiniciará no Modo Seguro (desktop mínimo, sem rede, sem Defender executando).

### 3b: Desabilitar TODOS os Serviços

No Modo Seguro, abra um PowerShell como Admin:

1. Clique em **Iniciar**
2. Digite `PowerShell`
3. Clique com botão direito em **Windows PowerShell** → **Executar como administrador**
4. Cole e execute este bloco inteiro:

```powershell
$services = @("WinDefend", "WdNisSvc", "WdNisDrv", "WdFilter", "WdBoot", "MDCoreSvc")
foreach ($svc in $services) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name "Start" -Value 4 -Type DWord
    Write-Host "$svc disabled" -ForegroundColor Green
}
```

Você deve ver:

```
WinDefend disabled
WdNisSvc disabled
WdNisDrv disabled
WdFilter disabled
WdBoot disabled
MDCoreSvc disabled
```

Sem erros = sucesso.

### Se o PowerShell não estiver disponível no Modo Seguro, use o Prompt de Comando (Admin):

```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WinDefend" /v Start /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WdNisSvc" /v Start /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WdNisDrv" /v Start /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WdFilter" /v Start /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WdBoot" /v Start /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\MDCoreSvc" /v Start /t REG_DWORD /d 4 /f
```

### O que cada serviço faz:

| Serviço | Processo | Função |
|---------|----------|--------|
| WinDefend | MsMpEng.exe | Engine principal do antimalware |
| WdNisSvc | NisSrv.exe | Serviço de inspeção de rede |
| WdNisDrv | WdNisDrv.sys | Driver kernel de inspeção de rede |
| WdFilter | WdFilter.sys | Mini-filtro de sistema de arquivos em tempo real |
| WdBoot | WdBoot.sys | Driver antimalware de inicialização |
| MDCoreSvc | mpdefendercoreservice.exe | Serviço Core do Microsoft Defender (adicionado em atualizações recentes) |

Definir `Start = 4` significa **Desabilitado** — o serviço nunca iniciará.

### 3c: Sair do Modo Seguro e Reiniciar Normalmente

Ainda no PowerShell Admin no Modo Seguro:

```powershell
bcdedit /deletevalue "{current}" safeboot
Restart-Computer
```

Ou no Prompt de Comando:

```cmd
bcdedit /deletevalue {current} safeboot
shutdown /r /t 0
```

---

## Passo 4: Verificar

Após reiniciar normalmente:

1. Abra **Gerenciador de Tarefas** → aba **Detalhes**
2. Procure `MsMpEng.exe` — **NÃO** deve estar listado
3. Procure `NisSrv.exe` — **NÃO** deve estar listado
4. Procure `mpdefendercoreservice.exe` — **NÃO** deve estar listado
5. Verifique uso de CPU — deve estar significativamente menor
6. Verifique RAM — deve haver mais memória livre
7. Sem ícone de escudo de segurança na barra de tarefas

---

## Após Windows Update (Procedimento de Re-execução)

O Windows Update pode redefinir políticas do Defender e reativar serviços. Se o Defender voltar após uma atualização, siga esta sequência:

### 1. Desativar Proteção contra Violação (GUI)

Configurações → Privacidade e Segurança → Segurança do Windows → Proteção contra vírus e ameaças → Gerenciar configurações → Proteção contra Violação → **Desligado**

### 2. Executar o script de desativação (PowerShell Admin)

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd ~\Downloads
.\disable-defender.ps1
```

### 3. Entrar no Modo Seguro

```powershell
bcdedit /set "{current}" safeboot minimal
Restart-Computer
```

### 4. Desabilitar todos os serviços (PowerShell Admin no Modo Seguro)

```powershell
$services = @("WinDefend", "WdNisSvc", "WdNisDrv", "WdFilter", "WdBoot", "MDCoreSvc")
foreach ($svc in $services) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name "Start" -Value 4 -Type DWord
    Write-Host "$svc disabled" -ForegroundColor Green
}
```

### 5. Sair do Modo Seguro e reiniciar

```powershell
bcdedit /deletevalue "{current}" safeboot
Restart-Computer
```

### 6. Verificar

Gerenciador de Tarefas → Detalhes → confirme que `MsMpEng.exe` e `mpdefendercoreservice.exe` sumiram.

---

## Solução de Problemas

### Central de Segurança ainda mostra avisos

1. Clique com botão direito no ícone de escudo na barra de tarefas → Remover ícone
2. Ou: **Configurações** → **Personalização** → **Barra de tarefas** → **Outros ícones da bandeja do sistema** → desativar Central de Segurança

### Modo Seguro não inicia via bcdedit

1. Segure **Shift** enquanto clica em **Reiniciar** no Menu Iniciar
2. Navegue: **Solução de problemas** → **Opções avançadas** → **Configurações de Inicialização** → **Reiniciar**
3. Pressione **4** para Modo Seguro
4. Continue a partir do Passo 3b

### Sintaxe do bcdedit — PowerShell vs CMD

PowerShell exige aspas ao redor de `{current}`:

```powershell
bcdedit /set "{current}" safeboot minimal
```

CMD não exige:

```cmd
bcdedit /set {current} safeboot minimal
```

---

## Resumo Completo dos Serviços

| Serviço/Recurso | Ação | Método | Impacto |
|-----------------|------|--------|---------|
| Windows Defender | Desabilitado | Modo Seguro | Sem varredura antivírus |
| Defender Core Service | Desabilitado | Modo Seguro | Sem processo core do Defender |
| Inspeção de Rede | Desabilitado | Modo Seguro | Sem varredura de tráfego |
| Driver de Boot | Desabilitado | Modo Seguro | Sem varredura na inicialização |
| Filtro de Sistema de Arquivos | Desabilitado | Modo Seguro | Sem varredura em tempo real |
| SmartScreen | Desabilitado | Script | Sem verificação de reputação |
| Proteção contra Violação | Desligado | GUI Manual | Permite alterações via script |
| SysMain/Superfetch | Desabilitado | Script | Libera RAM |
| DiagTrack/Telemetria | Desabilitado | Script | Sem envio de dados para Microsoft |
| GameBar/GameDVR | Desabilitado | Script | Sem overlay de jogos |
| NVIDIA Display | Desabilitado | Script | Sem GPU na VM |
| Windows Search | **MANTIDO** | — | Pesquisa do Outlook depende dele |
| Windows Update | **MANTIDO** | — | Manual para atualizações do Office |

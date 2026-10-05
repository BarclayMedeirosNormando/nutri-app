import '../services/apps_script_client.dart';

/// Única função que transforma erros em texto para o usuário.
/// Nunca mostra a exceção crua nem o endereço do backend.
String friendlyError(Object error) {
  if (error is ApiException) {
    switch (error.code) {
      case 'network':
      case 'timeout':
        return 'Sem conexão com a internet. Tente novamente.';
      case 'invalid_credentials':
        return 'Senha incorreta.';
      case 'locked':
        return 'Muitas tentativas. Aguarde 15 minutos e tente de novo.';
      case 'unauthorized':
        return 'Sua sessão expirou. Entre novamente.';
      case 'not_configured':
        return 'O acesso ainda não foi configurado. Faça o primeiro acesso.';
      case 'already_configured':
        return 'O primeiro acesso já foi feito.';
      case 'invalid_setup_code':
        return 'Código de configuração inválido.';
      case 'weak_password':
        return 'A senha deve ter pelo menos 10 caracteres.';
      case 'not_configured_app':
        return 'O aplicativo não está configurado corretamente.';
    }
  }
  return 'Não foi possível concluir. Tente novamente em instantes.';
}

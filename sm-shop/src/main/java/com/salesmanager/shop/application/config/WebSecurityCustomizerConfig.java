package com.salesmanager.shop.application.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.WebSecurity;
import org.springframework.security.web.util.matcher.AntPathRequestMatcher;

@Configuration
public class WebSecurityCustomizerConfig {

	@Bean
	public org.springframework.security.config.annotation.web.configuration.WebSecurityCustomizer webSecurityCustomizer() {
		return new org.springframework.security.config.annotation.web.configuration.WebSecurityCustomizer() {
			@Override
			public void customize(WebSecurity web) {
				web.ignoring().requestMatchers(
						new AntPathRequestMatcher("/"),
						new AntPathRequestMatcher("/error"),
						new AntPathRequestMatcher("/resources/**"),
						new AntPathRequestMatcher("/static/**"),
						new AntPathRequestMatcher("/services/public/**"),
						new AntPathRequestMatcher("/swagger-ui.html")
				);
			}
		};
	}

}

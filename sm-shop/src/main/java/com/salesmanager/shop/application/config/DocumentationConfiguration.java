package com.salesmanager.shop.application.config;

import org.springdoc.core.models.GroupedOpenApi;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class DocumentationConfiguration {

	/**
	 * http://localhost:8080/swagger-ui.html#/
	 */

	@Bean
	public GroupedOpenApi shopApi() {
		return GroupedOpenApi.builder()
				.group("shop-api")
				.pathsToMatch("/api/**")
				.build();
	}

	@Bean
	public GroupedOpenApi publicApi() {
		return GroupedOpenApi.builder()
				.group("public-api")
				.pathsToMatch("/services/public/**", "/shop/**")
				.build();
	}

}

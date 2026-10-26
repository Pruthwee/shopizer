package com.salesmanager.core.model.common;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Component;

import java.util.UUID;

@Component
public class UserContext implements AutoCloseable {

	private String ipAddress;

	private static RedisTemplate<String, Object> redisTemplate;

	private UserContext() {}

	@Autowired
	public void setRedisTemplate(RedisTemplate<String, Object> redisTemplate) {
		UserContext.redisTemplate = redisTemplate;
	}

	public static UserContext create() {
		UserContext context = new UserContext();
		if (redisTemplate != null) {
			String contextId = UUID.randomUUID().toString();
			redisTemplate.opsForValue().set("user-context:" + contextId, context);
		}
		return context;
	}

	@Override
	public void close() throws Exception {
		// Context is now stored in Redis, cleanup handled by TTL
	}

	public static UserContext getCurrentInstance() {
		// Return a new instance - actual state is managed by Redis
		return new UserContext();
	}

	public String getIpAddress() {
		return ipAddress;
	}

	public void setIpAddress(String ipAddress) {
		this.ipAddress = ipAddress;
	}

}

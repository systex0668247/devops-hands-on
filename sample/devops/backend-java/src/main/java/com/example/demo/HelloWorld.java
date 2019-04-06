package com.example.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Hello World!!!
 */
@RestController
@RequestMapping(path = "/")
public class HelloWorld {

    @GetMapping(path="/")
    public String hello() throws Exception
    {
        return System.getenv("HOSTNAME");
    }
}
